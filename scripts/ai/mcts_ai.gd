## PARKED / not the active AI. Kept as a tested experiment. Vanilla random-rollout
## MCTS plays the capture-race poorly: on a 9x9 board random play almost never
## reaches "3 captures" within the rollout depth, so ~90% of rollouts are draws
## (no signal) and it defaults to expansion order (bottom-right corner). To revive
## it, give it capture/atari-aware rollouts + a position evaluation (e.g. reuse
## HeuristicAI as the rollout policy). The game uses HeuristicAI instead.
##
## Monte Carlo Tree Search opponent for the capture-race (first to WIN_CAPTURES
## captures wins, 提3子). Pure GDScript — no external dependencies, web/itch safe.
## Reuses GoRules/GroupAnalysis for legality + capture resolution.
##
## Each call to choose_move() runs `iterations` of: select -> expand -> rollout
## -> backpropagate, then returns the most-visited root child's move.
##
## Tree nodes intentionally do NOT store a parent pointer (that would create a
## reference cycle that GDScript's RefCounted won't free). Instead the selection
## path is tracked as a list and used for backpropagation.
class_name MctsAI
extends RefCounted

const NO_MOVE := Vector2i(-1, -1)
const WIN_CAPTURES := 3
const DEFAULT_ITERATIONS := 220
const MAX_ROLLOUT_DEPTH := 30
const EXPLORATION := 1.41421356237  # ~sqrt(2), the UCB1 constant
const ROLLOUT_SAMPLE_TRIES := 40    # rejection-sampling attempts per rollout step

## One node of the search tree (a position + MCTS stats). No parent pointer.
class SearchNode:
	extends RefCounted
	var state: BoardState
	var to_move: int
	var cap_black: int
	var cap_white: int
	var ko  # BoardState or null — the position this move may not recreate
	var move: Vector2i  # move that produced this node; NO_MOVE at root
	var children: Array = []
	var untried = null  # Array[Vector2i] computed lazily; null = not computed yet
	var visits: int = 0
	var wins: float = 0.0  # credit for the player who MOVED into this node

	func _init(p_state: BoardState, p_to_move: int, p_cb: int, p_cw: int, p_ko, p_move: Vector2i) -> void:
		state = p_state
		to_move = p_to_move
		cap_black = p_cb
		cap_white = p_cw
		ko = p_ko
		move = p_move

## Returns the AI's chosen move for `color`, or NO_MOVE if no legal move exists.
## cap_black / cap_white are the CURRENT cumulative capture counts (win at WIN_CAPTURES).
static func choose_move(state: BoardState, color: int, cap_black: int, cap_white: int, ko_forbidden: BoardState = null, iterations: int = DEFAULT_ITERATIONS) -> Vector2i:
	var root := SearchNode.new(state, color, cap_black, cap_white, ko_forbidden, NO_MOVE)
	root.untried = _legal_moves(state, color, ko_forbidden)
	if root.untried.is_empty():
		return NO_MOVE
	for _i in iterations:
		var path := _tree_policy(root)
		var leaf: SearchNode = path[path.size() - 1]
		var winner := _rollout(leaf)
		_backpropagate(path, winner)
	var best: SearchNode = null
	for c in root.children:
		if best == null or c.visits > best.visits:
			best = c
	return best.move if best != null else root.untried[0]

# --- Selection / expansion -------------------------------------------------

## Descends from root via UCB1, returning the path (root..leaf) to evaluate.
static func _tree_policy(root: SearchNode) -> Array:
	var path: Array = [root]
	var n := root
	while true:
		if _capture_winner(n) != -2:
			return path  # terminal: someone has already won
		if n.untried == null:
			n.untried = _legal_moves(n.state, n.to_move, n.ko)
		if not n.untried.is_empty():
			path.append(_expand(n))
			return path
		if n.children.is_empty():
			return path  # terminal: no legal move (treated as a draw)
		n = _best_uct(n)
		path.append(n)
	return path  # unreachable; loop only exits via return

static func _expand(n: SearchNode) -> SearchNode:
	var move: Vector2i = n.untried.pop_back()
	var result := GoRules.place(n.state, move.x, move.y, n.to_move, n.ko)
	var caps: int = result["captured"].size()
	var cb := n.cap_black + (caps if n.to_move == BoardState.Point.BLACK else 0)
	var cw := n.cap_white + (caps if n.to_move == BoardState.Point.WHITE else 0)
	var child := SearchNode.new(result["state"], _opp(n.to_move), cb, cw, n.state, move)
	n.children.append(child)
	return child

static func _best_uct(n: SearchNode) -> SearchNode:
	var best: SearchNode = null
	var best_val := -INF
	var ln_n := log(float(n.visits))
	for c in n.children:
		var exploit: float = c.wins / float(c.visits)
		var explore: float = EXPLORATION * sqrt(ln_n / float(c.visits))
		var val: float = exploit + explore
		if val > best_val:
			best_val = val
			best = c
	return best

# --- Rollout ---------------------------------------------------------------

static func _rollout(node: SearchNode) -> int:
	var w := _capture_winner(node)
	if w != -2:
		return w
	var st := node.state
	var tm := node.to_move
	var cb := node.cap_black
	var cw := node.cap_white
	var ko = node.ko
	for _d in MAX_ROLLOUT_DEPTH:
		var mv := _rollout_move(st, tm, ko)
		if mv == NO_MOVE:
			break
		var result := GoRules.place(st, mv.x, mv.y, tm, ko)
		var caps: int = result["captured"].size()
		if tm == BoardState.Point.BLACK:
			cb += caps
		else:
			cw += caps
		ko = st
		st = result["state"]
		if cb >= WIN_CAPTURES:
			return BoardState.Point.BLACK
		if cw >= WIN_CAPTURES:
			return BoardState.Point.WHITE
		tm = _opp(tm)
	# Depth cap reached with no win: decide by who has captured more.
	if cb > cw:
		return BoardState.Point.BLACK
	if cw > cb:
		return BoardState.Point.WHITE
	return -1  # draw

## Picks a random legal move via rejection sampling (cheap); falls back to a
## full scan if random sampling keeps missing (board nearly full).
static func _rollout_move(state: BoardState, color: int, ko) -> Vector2i:
	for _t in ROLLOUT_SAMPLE_TRIES:
		var x := randi() % state.size
		var y := randi() % state.size
		if state.is_empty(x, y) and GoRules.place(state, x, y, color, ko)["ok"]:
			return Vector2i(x, y)
	var moves := _legal_moves(state, color, ko)
	if moves.is_empty():
		return NO_MOVE
	return moves[randi() % moves.size()]

# --- Backprop / helpers ----------------------------------------------------

static func _backpropagate(path: Array, winner: int) -> void:
	for i in path.size():
		var node: SearchNode = path[i]
		node.visits += 1
		if i > 0:
			var mover: int = path[i - 1].to_move  # who played the move into this node
			if winner == mover:
				node.wins += 1.0
			elif winner == -1:
				node.wins += 0.5  # draw

## -2 = not terminal by captures; otherwise the winning color.
static func _capture_winner(n: SearchNode) -> int:
	if n.cap_black >= WIN_CAPTURES:
		return BoardState.Point.BLACK
	if n.cap_white >= WIN_CAPTURES:
		return BoardState.Point.WHITE
	return -2

static func _legal_moves(state: BoardState, color: int, ko) -> Array:
	var moves: Array = []
	for y in state.size:
		for x in state.size:
			if state.is_empty(x, y) and GoRules.place(state, x, y, color, ko)["ok"]:
				moves.append(Vector2i(x, y))
	return moves

static func _opp(color: int) -> int:
	return BoardState.Point.WHITE if color == BoardState.Point.BLACK else BoardState.Point.BLACK

## Tactical Go opponent for the capture-race (first to 3 captures wins, 提3子).
## Pure GDScript — no dependencies. Scores every legal move by simple Go tactics
## and plays the best (random among ties). This is the active opponent.
##
## Priorities (high -> low):
##   1. Capture enemy stones (it's the win condition) — biggest capture first.
##   2. Rescue your own group(s) sitting in atari (1 liberty).
##   3. Don't play into self-atari (handing the opponent a free capture).
##   4. Put enemy group(s) into atari (threaten to capture next).
##   5. Prefer moves that give your own group more liberties (healthier shape).
class_name HeuristicAI
extends RefCounted

const NO_MOVE := Vector2i(-1, -1)

const W_CAPTURE := 1000     # per captured stone
const W_SAVE_ATARI := 300   # per own group rescued from atari
const W_SELF_ATARI := -500  # leaving the new group on a single liberty (no capture)
const W_ENEMY_ATARI := 120  # per enemy group newly put into atari near the move
const W_LIBERTY := 3        # per liberty of the resulting own group

static func choose_move(state: BoardState, color: int, ko_forbidden: BoardState = null) -> Vector2i:
	var enemy := _opp(color)
	var my_atari_before := _atari_group_count(state, color)
	var best_score := -INF
	var best_moves: Array[Vector2i] = []
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			if not state.is_empty(x, y):
				continue
			var result := GoRules.place(state, x, y, color, ko_forbidden)
			if not result["ok"]:
				continue
			var rs: BoardState = result["state"]
			var caps: int = result["captured"].size()
			var own_group := GroupAnalysis.group_at(rs, x, y)
			var own_libs := GroupAnalysis.count_liberties(rs, own_group)

			var score := 0.0
			score += float(W_CAPTURE * caps)
			if caps == 0 and own_libs == 1:
				score += W_SELF_ATARI
			var saved := my_atari_before - _atari_group_count(rs, color)
			if saved > 0:
				score += float(W_SAVE_ATARI * saved)
			score += float(W_ENEMY_ATARI * _enemy_ataris_near(rs, x, y, enemy))
			score += float(W_LIBERTY * own_libs)

			if score > best_score:
				best_score = score
				best_moves = [Vector2i(x, y)]
			elif score == best_score:
				best_moves.append(Vector2i(x, y))
	if best_moves.is_empty():
		return NO_MOVE
	return best_moves[randi() % best_moves.size()]

## Number of distinct `color` groups that have exactly one liberty (in atari).
static func _atari_group_count(state: BoardState, color: int) -> int:
	var seen := {}
	var count := 0
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			if state.get_point(x, y) != color:
				continue
			var key := Vector2i(x, y)
			if seen.has(key):
				continue
			var group := GroupAnalysis.group_at(state, x, y)
			for p in group:
				seen[p] = true
			if GroupAnalysis.count_liberties(state, group) == 1:
				count += 1
	return count

## Number of distinct enemy groups orthogonally adjacent to (x, y) that are now
## in atari (exactly one liberty) — i.e. threatened by this move.
static func _enemy_ataris_near(state: BoardState, x: int, y: int, enemy: int) -> int:
	var seen := {}
	var count := 0
	for d in GroupAnalysis.NEIGHBORS:
		var n := Vector2i(x + d.x, y + d.y)
		if not state.in_bounds(n.x, n.y):
			continue
		if state.get_point(n.x, n.y) != enemy or seen.has(n):
			continue
		var group := GroupAnalysis.group_at(state, n.x, n.y)
		for p in group:
			seen[p] = true
		if GroupAnalysis.count_liberties(state, group) == 1:
			count += 1
	return count

static func _opp(color: int) -> int:
	return BoardState.Point.WHITE if color == BoardState.Point.BLACK else BoardState.Point.BLACK

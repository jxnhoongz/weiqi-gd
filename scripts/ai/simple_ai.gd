## A simple capture-greedy Go opponent. Pure logic (no Godot nodes) so it is
## unit-testable. Scores every legal move as (captured*100 + own liberties) and
## plays the best, choosing randomly among ties so games vary.
class_name SimpleAI
extends RefCounted

const NO_MOVE := Vector2i(-1, -1)

## Best move for `color` given `ko_forbidden`, or NO_MOVE if none is legal.
static func choose_move(state: BoardState, color: int, ko_forbidden: BoardState = null) -> Vector2i:
	var best_score := -1
	var best_moves: Array[Vector2i] = []
	for y in state.size:
		for x in state.size:
			if not state.is_empty(x, y):
				continue
			var result := GoRules.place(state, x, y, color, ko_forbidden)
			if not result["ok"]:
				continue
			var new_state: BoardState = result["state"]
			var own_group := GroupAnalysis.group_at(new_state, x, y)
			var liberties := GroupAnalysis.count_liberties(new_state, own_group)
			var score: int = int(result["captured"].size()) * 100 + liberties
			if score > best_score:
				best_score = score
				best_moves = [Vector2i(x, y)]
			elif score == best_score:
				best_moves.append(Vector2i(x, y))
	if best_moves.is_empty():
		return NO_MOVE
	return best_moves[randi() % best_moves.size()]

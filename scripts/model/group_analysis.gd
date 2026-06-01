## Pure board analysis: connected groups and their liberties. No Godot deps.
class_name GroupAnalysis
extends RefCounted

# Orthogonal neighbor offsets (Go connects up/down/left/right, never diagonally).
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## All coords in the connected same-color group containing (x, y).
## Returns [] if (x, y) is empty. (Flood fill.)
static func group_at(state: BoardState, x: int, y: int) -> Array:
	var color := state.get_point(x, y)
	if color == BoardState.Point.EMPTY:
		return []
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	var group: Array = []
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		group.append(p)
		for d in NEIGHBORS:
			var n := p + d
			if state.in_bounds(n.x, n.y) and not seen.has(n) \
					and state.get_point(n.x, n.y) == color:
				stack.append(n)
	return group

## Count of distinct EMPTY points orthogonally adjacent to the group.
static func count_liberties(state: BoardState, group: Array) -> int:
	var libs := {}
	for p in group:
		for d in NEIGHBORS:
			var n: Vector2i = p + d
			if state.in_bounds(n.x, n.y) \
					and state.get_point(n.x, n.y) == BoardState.Point.EMPTY:
				libs[n] = true
	return libs.size()

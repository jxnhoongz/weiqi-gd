## Pure Go move resolution. No Godot deps. Milestone 2 = capture only;
## ko and suicide prevention arrive in Milestone 3.
class_name GoRules
extends RefCounted

## Places `color` at (x, y) on a COPY of `state`, then removes any ENEMY group
## adjacent to (x, y) that now has zero liberties.
## Returns { "state": BoardState, "captured": Array[Vector2i] }.
## Assumes (x, y) is in bounds and empty (the caller guards this).
static func place(state: BoardState, x: int, y: int, color: int) -> Dictionary:
	var new_state := state.with_point(x, y, color)
	var enemy := _opponent(color)
	var captured: Array = []
	var checked := {}
	for d in GroupAnalysis.NEIGHBORS:
		var n := Vector2i(x + d.x, y + d.y)
		if not new_state.in_bounds(n.x, n.y):
			continue
		if new_state.get_point(n.x, n.y) != enemy:
			continue
		if checked.has(n):
			continue
		var group := GroupAnalysis.group_at(new_state, n.x, n.y)
		for p in group:
			checked[p] = true
		if GroupAnalysis.count_liberties(new_state, group) == 0:
			for p in group:
				new_state = new_state.with_point(p.x, p.y, BoardState.Point.EMPTY)
				captured.append(p)
	return {"state": new_state, "captured": captured}

static func _opponent(color: int) -> int:
	return BoardState.Point.WHITE if color == BoardState.Point.BLACK else BoardState.Point.BLACK

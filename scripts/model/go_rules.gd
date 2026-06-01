## Pure Go move resolution: capture (M2) + suicide & ko legality (M3). No Godot deps.
class_name GoRules
extends RefCounted

## Resolves playing `color` at (x, y) on a COPY of `state`.
## `ko_forbidden` (optional) is the board position this move must NOT recreate.
## Returns { "ok": bool, "reason": String, "state": BoardState, "captured": Array }.
##   ok=false reasons: "suicide", "ko". On rejection, state = the unchanged input.
## Assumes (x, y) is in bounds and empty (the caller guards this).
static func place(state: BoardState, x: int, y: int, color: int, ko_forbidden: BoardState = null) -> Dictionary:
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

	# Suicide: after captures, the placed stone's own group must have a liberty.
	var own_group := GroupAnalysis.group_at(new_state, x, y)
	if GroupAnalysis.count_liberties(new_state, own_group) == 0:
		return _rejected(state, "suicide")

	# Ko: this move may not recreate the forbidden previous position.
	if ko_forbidden != null and new_state.equals(ko_forbidden):
		return _rejected(state, "ko")

	return {"ok": true, "reason": "", "state": new_state, "captured": captured}

static func _rejected(state: BoardState, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "state": state, "captured": []}

static func _opponent(color: int) -> int:
	return BoardState.Point.WHITE if color == BoardState.Point.BLACK else BoardState.Point.BLACK

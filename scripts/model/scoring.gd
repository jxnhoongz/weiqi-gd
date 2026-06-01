## Territory / area scoring ("地盘"). Pure logic, no Godot deps.
##
## Area control = each colour's stones on the board PLUS empty regions that are
## bordered by only that colour. Empty regions touching both colours (or none)
## are neutral (dame). NOTE: this is "naive" scoring — it does not resolve dead
## stones (which in real Go needs both players to agree), so it reflects raw
## board control, good for "who controls more", not tournament-exact results.
class_name Scoring
extends RefCounted

## Returns { "black": int, "white": int, "neutral": int } area counts.
static func area(state: BoardState) -> Dictionary:
	var black := 0
	var white := 0
	var neutral := 0
	var visited := {}  # empty points already assigned to a region
	for y in state.size:
		for x in state.size:
			var p := state.get_point(x, y)
			if p == BoardState.Point.BLACK:
				black += 1
				continue
			if p == BoardState.Point.WHITE:
				white += 1
				continue
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			# Flood-fill this empty region, tracking which colours border it.
			var region_size := 0
			var borders := {}
			var stack: Array[Vector2i] = [start]
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				if visited.has(c):
					continue
				visited[c] = true
				region_size += 1
				for d in GroupAnalysis.NEIGHBORS:
					var n := c + d
					if not state.in_bounds(n.x, n.y):
						continue
					var np := state.get_point(n.x, n.y)
					if np == BoardState.Point.EMPTY:
						if not visited.has(n):
							stack.append(n)
					else:
						borders[np] = true
			if borders.size() == 1:
				if borders.has(BoardState.Point.BLACK):
					black += region_size
				else:
					white += region_size
			else:
				neutral += region_size
	return {"black": black, "white": white, "neutral": neutral}

## BLACK / WHITE if one controls more area, else EMPTY for a tie.
static func winner(state: BoardState) -> int:
	var a := area(state)
	if a["black"] > a["white"]:
		return BoardState.Point.BLACK
	if a["white"] > a["black"]:
		return BoardState.Point.WHITE
	return BoardState.Point.EMPTY

## Immutable 9x9 Go board state. Mutating methods return a NEW BoardState
## and never change the existing instance.
class_name BoardState
extends RefCounted

const SIZE := 9

enum Point { EMPTY, BLACK, WHITE }

# Flat row-major array of SIZE*SIZE Point values. Treated as immutable.
var _cells: PackedInt32Array

func _init(cells: PackedInt32Array = PackedInt32Array()) -> void:
	if cells.is_empty():
		_cells = PackedInt32Array()
		_cells.resize(SIZE * SIZE)
		_cells.fill(Point.EMPTY)
	else:
		assert(cells.size() == SIZE * SIZE, "BoardState requires SIZE*SIZE cells")
		_cells = cells

static func empty() -> BoardState:
	return BoardState.new()

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE

func get_point(x: int, y: int) -> int:
	assert(in_bounds(x, y), "get_point out of bounds")
	return _cells[y * SIZE + x]

func is_empty(x: int, y: int) -> bool:
	return get_point(x, y) == Point.EMPTY

## Returns a NEW BoardState with (x, y) set to `color`. Does not mutate self.
func with_point(x: int, y: int, color: int) -> BoardState:
	assert(in_bounds(x, y), "with_point out of bounds")
	var copy := _cells.duplicate()
	copy[y * SIZE + x] = color
	return BoardState.new(copy)

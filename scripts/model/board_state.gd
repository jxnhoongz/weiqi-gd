## Immutable Go board state of any square size (9, 19, …). Mutating methods
## return a NEW BoardState and never change the existing instance.
class_name BoardState
extends RefCounted

const DEFAULT_SIZE := 9

enum Point { EMPTY, BLACK, WHITE }

var size: int  # board is size x size intersections
# Flat row-major array of size*size Point values. Treated as immutable.
var _cells: PackedInt32Array

func _init(p_size: int = DEFAULT_SIZE, cells: PackedInt32Array = PackedInt32Array()) -> void:
	size = p_size
	if cells.is_empty():
		_cells = PackedInt32Array()
		_cells.resize(size * size)
		_cells.fill(Point.EMPTY)
	else:
		assert(cells.size() == size * size, "BoardState requires size*size cells")
		_cells = cells

static func empty(p_size: int = DEFAULT_SIZE) -> BoardState:
	return BoardState.new(p_size)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < size and y >= 0 and y < size

func get_point(x: int, y: int) -> int:
	assert(in_bounds(x, y), "get_point out of bounds")
	return _cells[y * size + x]

func is_empty(x: int, y: int) -> bool:
	return get_point(x, y) == Point.EMPTY

## Returns a NEW BoardState with (x, y) set to `color`. Does not mutate self.
func with_point(x: int, y: int, color: int) -> BoardState:
	assert(in_bounds(x, y), "with_point out of bounds")
	var copy := _cells.duplicate()
	copy[y * size + x] = color
	return BoardState.new(size, copy)

## True if `other` is the same size with the exact same stones in the same places.
func equals(other: BoardState) -> bool:
	return size == other.size and _cells == other._cells

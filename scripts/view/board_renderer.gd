## Milestone 1 main scene root: paints the 9x9 board once, then places
## alternating black/white stones on click. No Go rules yet (no capture/ko).
extends Node2D

const SOURCE_ID := 0

# Board tile atlas coordinates (col, row) — see spec section 6.
const TILE_TL := Vector2i(0, 0)
const TILE_T := Vector2i(1, 0)
const TILE_TR := Vector2i(2, 0)
const TILE_L := Vector2i(0, 1)
const TILE_C := Vector2i(1, 1)
const TILE_R := Vector2i(2, 1)
const TILE_BL := Vector2i(0, 2)
const TILE_B := Vector2i(1, 2)
const TILE_BR := Vector2i(2, 2)
const TILE_STAR := Vector2i(0, 3)
const TILE_STONE_WHITE := Vector2i(1, 3)
const TILE_STONE_BLACK := Vector2i(2, 3)

# 9x9 star points (0-indexed): the four 3-3 points and the center (天元).
const STAR_POINTS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6), Vector2i(4, 4),
]

const BOARD_TEXTURE_PATH := "res://assets/themes/kaya/go-board.png"

@onready var board_layer: TileMapLayer = $BoardLayer
@onready var stone_layer: TileMapLayer = $StoneLayer

var _state: BoardState
var _current_color: int = BoardState.Point.BLACK

func _ready() -> void:
	var texture: Texture2D = load(BOARD_TEXTURE_PATH)
	if texture == null:
		push_error("Failed to load board texture: %s" % BOARD_TEXTURE_PATH)
		return
	var tileset := TilesetBuilder.build(texture)
	board_layer.tile_set = tileset
	stone_layer.tile_set = tileset
	_state = BoardState.empty()
	_paint_board()

func _paint_board() -> void:
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			board_layer.set_cell(Vector2i(x, y), SOURCE_ID, _board_tile(x, y))

func _board_tile(x: int, y: int) -> Vector2i:
	if Vector2i(x, y) in STAR_POINTS:
		return TILE_STAR
	var last := BoardState.SIZE - 1
	var left := x == 0
	var right := x == last
	var top := y == 0
	var bottom := y == last
	if top and left:
		return TILE_TL
	if top and right:
		return TILE_TR
	if bottom and left:
		return TILE_BL
	if bottom and right:
		return TILE_BR
	if top:
		return TILE_T
	if bottom:
		return TILE_B
	if left:
		return TILE_L
	if right:
		return TILE_R
	return TILE_C

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := stone_layer.local_to_map(stone_layer.get_local_mouse_position())
		_try_place(cell.x, cell.y)

func _try_place(x: int, y: int) -> void:
	if not _state.in_bounds(x, y):
		return
	if not _state.is_empty(x, y):
		return
	_state = _state.with_point(x, y, _current_color)
	var atlas := TILE_STONE_BLACK if _current_color == BoardState.Point.BLACK else TILE_STONE_WHITE
	stone_layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas)
	_current_color = BoardState.Point.WHITE if _current_color == BoardState.Point.BLACK else BoardState.Point.BLACK

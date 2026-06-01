## Milestone 1 main scene root: paints the 9x9 board once, then places
## alternating black/white stones on click. No Go rules yet (no capture/ko).
##
## The board is drawn on a TileMapLayer. Stones are drawn as Sprite2D nodes
## "sliced" from the same atlas via AtlasTexture, so they can be scaled
## independently of the 32px grid (see STONE_SCALE) and overlap slightly,
## like real Go stones.
class_name BoardRenderer
extends Node2D

const SOURCE_ID := 0
const TILE_PX := 32

## Visual size of stones relative to a grid cell. 1.0 = exactly one cell.
## Non-integer values (e.g. 1.5) may look slightly uneven; 2.0 is crispest.
const STONE_SCALE := 1.5

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

# Stone pixel regions inside go-board.png (row 3 = star, white, black).
const STONE_REGION_WHITE := Rect2(32, 96, 32, 32)
const STONE_REGION_BLACK := Rect2(64, 96, 32, 32)

# 9x9 star points (0-indexed): the four 3-3 points and the center (天元).
const STAR_POINTS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6), Vector2i(4, 4),
]

const BOARD_TEXTURE_PATH := "res://assets/themes/kaya/go-board.png"

@onready var board_layer: TileMapLayer = $BoardLayer
@onready var stones: Node2D = $Stones

var _texture: Texture2D
var _state: BoardState
var _current_color: int = BoardState.Point.BLACK
# Maps a grid coord (Vector2i) to its placed Sprite2D, so stones can be
# removed later when capture is implemented.
var _stone_sprites: Dictionary = {}

func _ready() -> void:
	_texture = load(BOARD_TEXTURE_PATH)
	if _texture == null:
		push_error("Failed to load board texture: %s" % BOARD_TEXTURE_PATH)
		return
	board_layer.tile_set = TilesetBuilder.build(_texture)
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

## Which pixel rectangle of the atlas holds the stone for `color`.
static func stone_region(color: int) -> Rect2:
	return STONE_REGION_BLACK if color == BoardState.Point.BLACK else STONE_REGION_WHITE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := board_layer.local_to_map(board_layer.get_local_mouse_position())
		_try_place(cell.x, cell.y)

func _try_place(x: int, y: int) -> void:
	if not _state.in_bounds(x, y):
		return
	if not _state.is_empty(x, y):
		return
	var result := GoRules.place(_state, x, y, _current_color)
	_state = result["state"]
	_add_stone_sprite(x, y, _current_color)
	for captured in result["captured"]:
		_remove_stone_sprite(captured.x, captured.y)
	_current_color = BoardState.Point.WHITE if _current_color == BoardState.Point.BLACK else BoardState.Point.BLACK

func _add_stone_sprite(x: int, y: int, color: int) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture
	atlas.region = stone_region(color)
	sprite.texture = atlas
	sprite.scale = Vector2(STONE_SCALE, STONE_SCALE)
	# Centre the stone on the intersection (tile centre = x*32 + 16).
	sprite.position = Vector2(x * TILE_PX + TILE_PX / 2.0, y * TILE_PX + TILE_PX / 2.0)
	stones.add_child(sprite)
	_stone_sprites[Vector2i(x, y)] = sprite

## Removes a placed stone (used when capture lands in a later milestone).
func _remove_stone_sprite(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if _stone_sprites.has(key):
		_stone_sprites[key].queue_free()
		_stone_sprites.erase(key)

## Main scene root / game controller.
## Paints the 9x9 board (pixel tileset), runs a title menu, and plays either
## Human-vs-AI or Human-vs-Human (hotseat). Win condition: first to capture 3
## stones (提3子). Stones are Sprite2D nodes sliced from the atlas so they can be
## scaled past one cell (STONE_SCALE). UI is plain Control nodes + a code-built
## flat Theme (no pixel art needed for the interface).
class_name BoardRenderer
extends Node2D

const SOURCE_ID := 0
const TILE_PX := 32
const STONE_SCALE := 1.5

## First player to capture this many stones wins (提3子).
const WIN_CAPTURES := 3

## In vs-AI mode the human plays Black (moves first); the AI plays White.
const HUMAN_COLOR := BoardState.Point.BLACK
const AI_COLOR := BoardState.Point.WHITE

## Which mode the game is in. NONE = the title menu is showing (no play yet).
enum Mode { NONE, VS_AI, VS_PLAYER }

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
const SNAP_SFX_PATH := "res://assets/audio/snap.mp3"

@onready var board_layer: TileMapLayer = $BoardLayer
@onready var stones: Node2D = $Stones
@onready var ui_root: Control = $HUD/UIRoot
# Top bar
@onready var black_label: Label = $HUD/UIRoot/TopBar/Margin/Row/BlackLabel
@onready var turn_label: Label = $HUD/UIRoot/TopBar/Margin/Row/TurnLabel
@onready var white_label: Label = $HUD/UIRoot/TopBar/Margin/Row/WhiteLabel
# Win panel
@onready var win_overlay: CenterContainer = $HUD/UIRoot/WinOverlay
@onready var result_label: Label = $HUD/UIRoot/WinOverlay/WinPanel/WinMargin/WinBox/ResultLabel
@onready var score_label: Label = $HUD/UIRoot/WinOverlay/WinPanel/WinMargin/WinBox/ScoreLabel
@onready var restart_button: Button = $HUD/UIRoot/WinOverlay/WinPanel/WinMargin/WinBox/RestartButton
@onready var menu_button: Button = $HUD/UIRoot/WinOverlay/WinPanel/WinMargin/WinBox/MenuButton
# Title menu
@onready var menu_overlay: CenterContainer = $HUD/UIRoot/MenuOverlay
@onready var play_ai_button: Button = $HUD/UIRoot/MenuOverlay/MenuPanel/MenuMargin/MenuBox/PlayAiButton
@onready var play_pvp_button: Button = $HUD/UIRoot/MenuOverlay/MenuPanel/MenuMargin/MenuBox/PlayPvpButton

var _texture: Texture2D
var _snap_player: AudioStreamPlayer  # plays the "snap" sfx on stone placement
var _state: BoardState
var _board_size: int = BoardState.DEFAULT_SIZE
var _current_color: int = BoardState.Point.BLACK
var _mode: int = Mode.NONE
# Board position just before the last move — what a ko (打劫) recapture would recreate.
var _prev_state: BoardState = null
# Cumulative captured-stone counts, keyed by the capturing color.
var _captures := {BoardState.Point.BLACK: 0, BoardState.Point.WHITE: 0}
var _game_over := false
# Maps a grid coord (Vector2i) to its placed Sprite2D.
var _stone_sprites: Dictionary = {}

func _ready() -> void:
	_texture = load(BOARD_TEXTURE_PATH)
	if _texture == null:
		push_error("Failed to load board texture: %s" % BOARD_TEXTURE_PATH)
		return
	board_layer.tile_set = TilesetBuilder.build(_texture)
	_paint_board()
	# Audio: a non-positional player for the stone-placement "snap".
	_snap_player = AudioStreamPlayer.new()
	_snap_player.stream = load(SNAP_SFX_PATH)
	add_child(_snap_player)
	ui_root.theme = _build_ui_theme()
	# Gold accent for the turn indicator (overrides the cream Label colour).
	turn_label.add_theme_color_override("font_color", Color(0.91, 0.75, 0.49))
	# Wire the buttons' `pressed` signals to handler functions.
	play_ai_button.pressed.connect(func() -> void: _start_game(Mode.VS_AI))
	play_pvp_button.pressed.connect(func() -> void: _start_game(Mode.VS_PLAYER))
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_show_menu)
	_show_menu()

# --- Board painting --------------------------------------------------------

func _paint_board() -> void:
	for y in _board_size:
		for x in _board_size:
			board_layer.set_cell(Vector2i(x, y), SOURCE_ID, _board_tile(x, y))

func _board_tile(x: int, y: int) -> Vector2i:
	if Vector2i(x, y) in STAR_POINTS:
		return TILE_STAR
	var last := _board_size - 1
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

# --- Game flow / modes -----------------------------------------------------

func _show_menu() -> void:
	_reset_board_state()
	_mode = Mode.NONE
	menu_overlay.visible = true
	win_overlay.visible = false
	_update_status()

func _start_game(mode: int) -> void:
	_reset_board_state()
	_mode = mode
	menu_overlay.visible = false
	win_overlay.visible = false
	_update_status()

func _on_restart_pressed() -> void:
	_start_game(_mode)  # replay the same mode

func _reset_board_state() -> void:
	for key in _stone_sprites.keys():
		_stone_sprites[key].queue_free()
	_stone_sprites.clear()
	_state = BoardState.empty()
	_prev_state = null
	_current_color = BoardState.Point.BLACK
	_captures = {BoardState.Point.BLACK: 0, BoardState.Point.WHITE: 0}
	_game_over = false

# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and _mode != Mode.NONE:
		_on_restart_pressed()
		return
	if _mode == Mode.NONE or _game_over:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _mode == Mode.VS_AI and _current_color != HUMAN_COLOR:
			return
		var cell := board_layer.local_to_map(board_layer.get_local_mouse_position())
		if _apply_move(cell.x, cell.y, _current_color) and not _game_over and _mode == Mode.VS_AI:
			_ai_turn()

## The AI (White) picks and plays its best move after the human moves.
func _ai_turn() -> void:
	if _mode != Mode.VS_AI or _game_over or _current_color != AI_COLOR:
		return
	var mv := HeuristicAI.choose_move(_state, AI_COLOR, _prev_state)
	if mv == HeuristicAI.NO_MOVE:
		return  # no legal move for the AI; rare on 9x9
	_apply_move(mv.x, mv.y, AI_COLOR)

## Applies a move for `color` if legal. Returns true if a stone was placed.
func _apply_move(x: int, y: int, color: int) -> bool:
	if _game_over:
		return false
	if not _state.in_bounds(x, y):
		return false
	if not _state.is_empty(x, y):
		return false
	var result := GoRules.place(_state, x, y, color, _prev_state)
	if not result["ok"]:
		return false
	var position_before_move := _state
	_state = result["state"]
	_add_stone_sprite(x, y, color)
	var captured: Array = result["captured"]
	for c in captured:
		_remove_stone_sprite(c.x, c.y)
	_captures[color] += captured.size()
	_prev_state = position_before_move
	if _captures[color] >= WIN_CAPTURES:
		_game_over = true
	else:
		_current_color = _opponent(color)
	_update_status()
	return true

func _opponent(color: int) -> int:
	return BoardState.Point.WHITE if color == BoardState.Point.BLACK else BoardState.Point.BLACK

# --- HUD --------------------------------------------------------------------

func _update_status() -> void:
	if black_label == null:
		return  # nodes not ready yet
	var b: int = _captures[BoardState.Point.BLACK]
	var w: int = _captures[BoardState.Point.WHITE]
	var vs_ai := _mode == Mode.VS_AI
	var black_name := "Black (You)" if vs_ai else "Black"
	var white_name := "White (AI)" if vs_ai else "White"
	black_label.text = "%s  %d / %d" % [black_name, b, WIN_CAPTURES]
	white_label.text = "%s  %d / %d" % [white_name, w, WIN_CAPTURES]
	if _game_over:
		turn_label.text = "Game over"
		var black_won := b >= WIN_CAPTURES
		if vs_ai:
			result_label.text = "You win! 提3子" if black_won else "AI wins! 提3子"
		else:
			result_label.text = "Black wins! 提3子" if black_won else "White wins! 提3子"
		score_label.text = "Black %d · White %d" % [b, w]
		win_overlay.visible = true
		return
	win_overlay.visible = false
	if _mode == Mode.NONE:
		turn_label.text = ""
	elif vs_ai:
		turn_label.text = "Your turn" if _current_color == HUMAN_COLOR else "AI to move"
	else:
		turn_label.text = "Black to move" if _current_color == BoardState.Point.BLACK else "White to move"

# --- Stones (sprites) -------------------------------------------------------

func _add_stone_sprite(x: int, y: int, color: int) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture
	atlas.region = stone_region(color)
	sprite.texture = atlas
	# Centre the stone on the intersection (tile centre = x*32 + 16).
	sprite.position = Vector2(x * TILE_PX + TILE_PX / 2.0, y * TILE_PX + TILE_PX / 2.0)
	# JUICE: start tiny and bounce up to size. TRANS_BACK overshoots past the
	# target then settles back — that "plonk" feel from the Juice Lab.
	sprite.scale = Vector2.ZERO
	stones.add_child(sprite)
	_stone_sprites[Vector2i(x, y)] = sprite
	var target := Vector2(STONE_SCALE, STONE_SCALE)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _snap_player and _snap_player.stream:
		_snap_player.play()

func _remove_stone_sprite(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if not _stone_sprites.has(key):
		return
	var sprite: Sprite2D = _stone_sprites[key]
	_stone_sprites.erase(key)
	# JUICE: pop (scale up) + fade out, with a little particle burst, instead of
	# vanishing instantly. Colour the bits to match the captured stone.
	var is_black := (sprite.texture as AtlasTexture).region == STONE_REGION_BLACK
	_capture_burst(sprite.position, Color(0.1, 0.1, 0.1) if is_black else Color(0.95, 0.93, 0.86))
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(sprite, "scale", sprite.scale * 1.4, 0.18)
	tw.tween_callback(sprite.queue_free)

## Flings a few small squares outward from `pos` (a capture "burst"). No art —
## just Polygon2D squares tweened outward and faded, then freed.
func _capture_burst(pos: Vector2, color: Color) -> void:
	for i in 8:
		var bit := Polygon2D.new()
		bit.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		bit.color = color
		bit.position = pos
		stones.add_child(bit)
		var angle := TAU * i / 8.0
		var dist := 16.0 + randf() * 12.0
		var dest := pos + Vector2(cos(angle), sin(angle)) * dist
		var tw := create_tween()
		tw.tween_property(bit, "position", dest, 0.3).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.3)
		tw.tween_callback(bit.queue_free)

# --- UI theme (flat, code-built — no art) ----------------------------------

## Builds one Theme applied to UIRoot; it cascades to all child Controls so the
## menu, buttons, top bar, and win panel share a consistent flat look.
func _build_ui_theme() -> Theme:
	var t := Theme.new()
	t.set_default_font_size(16)

	# Warm-wood palette pulled from the board (kaya) so the UI feels part of the game.
	var bg := Color(0.227, 0.173, 0.110)        # #3a2c1c deep wood brown
	var accent := Color(0.79, 0.63, 0.39)       # kaya gold (buttons)
	var accent_hover := Color(0.86, 0.71, 0.47)
	var accent_pressed := Color(0.69, 0.54, 0.33)
	var text := Color(0.937, 0.886, 0.776)      # #efe2c6 cream
	var dark_text := Color(0.14, 0.10, 0.05)

	var panel := StyleBoxFlat.new()
	panel.bg_color = bg
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(6)
	panel.border_color = Color(1, 1, 1, 0.06)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)

	for state in {"normal": accent, "hover": accent_hover, "pressed": accent_pressed}:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": accent, "hover": accent_hover, "pressed": accent_pressed}[state]
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", dark_text)
	t.set_color("font_hover_color", "Button", dark_text)
	t.set_color("font_pressed_color", "Button", dark_text)
	t.set_color("font_color", "Label", text)
	return t

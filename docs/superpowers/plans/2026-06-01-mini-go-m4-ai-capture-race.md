# Mini Go — Milestone 4 (revised): Capture-Race vs Simple AI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Play 9×9 Go against a simple computer opponent with a custom, fun win condition: **the first player to capture 3 stones (cumulative) wins (提3子)**. Full territory scoring is deferred to a future 19×19 expansion.

**Architecture:** A new pure, testable `SimpleAI.choose_move()` (capture-greedy: maximize captured stones, then own-group liberties, random among ties) reuses the existing `GoRules`/`GroupAnalysis` to only ever pick legal moves. The renderer gains: a per-color **capture tally**, a **win check** (≥3 → game over), a tiny **HUD label** (first on-screen UI) showing captures / turn / winner, a **restart** key, and an **AI turn** that auto-plays White after the human (Black) moves. Move application is refactored into one `_apply_move()` used by both human and AI.

**Tech Stack:** Godot 4.4.1, GDScript, GUT (headless).

**Reference spec:** `docs/superpowers/specs/2026-06-01-mini-go-design.md`. NOTE: this milestone intentionally replaces the spec's original "M4 full scoring" for the 9×9 v1; the finalize task records that decision.

**Conventions:**
- `GODOT` = `/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot`
- Test command: `$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- If a `class_name` isn't found on a fresh run, run `$GODOT --headless --path . --import` once, then re-run.
- From `/Users/jxn/dev/fun_side_proj/go`. Commit per task; do NOT push (controller pushes).

---

## File Structure (this milestone)

- Create `scripts/ai/simple_ai.gd` — `choose_move(state, color, ko_forbidden) -> Vector2i`.
- Create `tests/test_simple_ai.gd` — unit tests.
- Modify `scenes/main.tscn` — add a `HUD` CanvasLayer with a `StatusLabel`.
- Modify `scripts/view/board_renderer.gd` — capture tally, win, game-over, HUD, restart (Task 2); AI opponent (Task 3).

---

## Task 1: SimpleAI (capture-greedy) — TDD

**Files:** Create `scripts/ai/simple_ai.gd`, `tests/test_simple_ai.gd`

- [ ] **Step 1: Write the failing tests** — Create `tests/test_simple_ai.gd`:
```gdscript
extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE

func test_no_move_when_board_is_full() -> void:
	var s := BoardState.empty()
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			s = s.with_point(x, y, BLACK)
	assert_eq(SimpleAI.choose_move(s, WHITE), SimpleAI.NO_MOVE)

func test_chosen_move_is_always_legal() -> void:
	var s := BoardState.empty()
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_ne(mv, SimpleAI.NO_MOVE)
	assert_true(GoRules.place(s, mv.x, mv.y, BLACK)["ok"])

func test_takes_an_available_capture() -> void:
	# White stone at (0,0) in atari (black at (1,0)); the capturing move is (0,1).
	var s := BoardState.empty()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(0, 1), "only capturing move")
	assert_eq(GoRules.place(s, mv.x, mv.y, BLACK)["captured"].size(), 1)

func test_prefers_the_larger_capture() -> void:
	# Option A: capture 1 white at (0,0) by playing (0,1).
	# Option B: capture a 2-stone white group at (4,4),(5,4) by playing (6,4).
	var s := BoardState.empty()
	# Option A setup:
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	# Option B setup: white pair (4,4),(5,4) with only liberty (6,4).
	s = s.with_point(4, 4, WHITE)
	s = s.with_point(5, 4, WHITE)
	s = s.with_point(3, 4, BLACK)
	s = s.with_point(4, 3, BLACK)
	s = s.with_point(4, 5, BLACK)
	s = s.with_point(5, 3, BLACK)
	s = s.with_point(5, 5, BLACK)
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(6, 4), "should choose the move capturing 2, not 1")
	assert_eq(GoRules.place(s, mv.x, mv.y, BLACK)["captured"].size(), 2)
```

- [ ] **Step 2: Run — expect FAIL** (`SimpleAI` not declared).

- [ ] **Step 3: Implement** — Create `scripts/ai/simple_ai.gd`:
```gdscript
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
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
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
```

- [ ] **Step 4: Run — expect PASS** (4 new tests; ~33 total).

- [ ] **Step 5: Commit**
```bash
git add scripts/ai/simple_ai.gd tests/test_simple_ai.gd
git commit -m "feat: SimpleAI capture-greedy move chooser (TDD)"
```

---

## Task 2: Capture tally + win condition + HUD + restart (still hotseat)

**Files:** Modify `scenes/main.tscn`, `scripts/view/board_renderer.gd`

This task adds the win machinery and the first UI, but keeps BOTH colors clickable
(hotseat) so we can verify the win condition before adding the AI in Task 3.

- [ ] **Step 1: Add a HUD to the scene** — In `scenes/main.tscn`, add a CanvasLayer + Label.
Append these two nodes (after the `Camera2D` node) and bump `load_steps` if needed:
```
[node name="HUD" type="CanvasLayer" parent="."]

[node name="StatusLabel" type="Label" parent="HUD"]
offset_left = 8.0
offset_top = 8.0
offset_right = 568.0
offset_bottom = 48.0
theme_override_font_sizes/font_size = 18
text = "You: Black  ·  Captures — Black 0 / White 0"
```

- [ ] **Step 2: Add fields + win/HUD/restart logic to `board_renderer.gd`**

Add these constants near the top (after `const STONE_SCALE := 1.5`):
```gdscript
## Custom win condition for the 9x9 game: first to capture this many stones wins (提3子).
const WIN_CAPTURES := 3
```

Add these fields near the other `var` declarations (after `var _prev_state ...`):
```gdscript
# Cumulative captured-stone counts, keyed by the capturing color.
var _captures := {BoardState.Point.BLACK: 0, BoardState.Point.WHITE: 0}
var _game_over := false
```

Add the HUD reference next to the other `@onready` lines:
```gdscript
@onready var status_label: Label = $HUD/StatusLabel
```

At the END of `_ready()`, add:
```gdscript
	_update_status()
```

- [ ] **Step 3: Refactor move application into `_apply_move` and replace `_try_place`/`_unhandled_input`**

Replace the existing `_unhandled_input` and `_try_place` functions with:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()
		return
	if _game_over:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := board_layer.local_to_map(board_layer.get_local_mouse_position())
		_apply_move(cell.x, cell.y, _current_color)

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

func _update_status() -> void:
	if status_label == null:
		return
	var b: int = _captures[BoardState.Point.BLACK]
	var w: int = _captures[BoardState.Point.WHITE]
	if _game_over:
		var winner := "Black" if b >= WIN_CAPTURES else "White"
		status_label.text = "%s wins! (提3子)  Black %d · White %d   —   press R to restart" % [winner, b, w]
	else:
		var turn := "Black" if _current_color == BoardState.Point.BLACK else "White"
		status_label.text = "Turn: %s   ·   Captures — Black %d / White %d" % [turn, b, w]

func _reset() -> void:
	for key in _stone_sprites.keys():
		_stone_sprites[key].queue_free()
	_stone_sprites.clear()
	_state = BoardState.empty()
	_prev_state = null
	_current_color = BoardState.Point.BLACK
	_captures = {BoardState.Point.BLACK: 0, BoardState.Point.WHITE: 0}
	_game_over = false
	_update_status()
```

- [ ] **Step 4: Verify project loads + all tests pass**
```bash
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -3
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests|Passing|passed|failed" | tail -4
```
Expected: ~33 tests pass; no load errors.

- [ ] **Step 5: Commit**
```bash
git add scenes/main.tscn scripts/view/board_renderer.gd
git commit -m "feat: capture tally, 3-capture win, HUD label, restart (hotseat)"
```

---

## Task 3: Wire the SimpleAI opponent (you = Black, AI = White)

**Files:** Modify `scripts/view/board_renderer.gd`

- [ ] **Step 1: Add color-role constants** (after `const WIN_CAPTURES := 3`):
```gdscript
## The human plays Black (moves first); the AI plays White.
const HUMAN_COLOR := BoardState.Point.BLACK
const AI_COLOR := BoardState.Point.WHITE
```

- [ ] **Step 2: Restrict clicks to the human's turn, and trigger the AI after a human move**

Replace the mouse-click branch of `_unhandled_input` so it only accepts the human's
clicks and then lets the AI respond. Replace the whole `_unhandled_input` with:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()
		return
	if _game_over:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _current_color != HUMAN_COLOR:
			return
		var cell := board_layer.local_to_map(board_layer.get_local_mouse_position())
		if _apply_move(cell.x, cell.y, HUMAN_COLOR) and not _game_over:
			_ai_turn()

## The AI (White) picks and plays its best move.
func _ai_turn() -> void:
	if _game_over or _current_color != AI_COLOR:
		return
	var mv := SimpleAI.choose_move(_state, AI_COLOR, _prev_state)
	if mv == SimpleAI.NO_MOVE:
		return  # no legal move for the AI; leave the turn (rare on 9x9)
	_apply_move(mv.x, mv.y, AI_COLOR)
```

- [ ] **Step 3: Verify project loads + tests still pass**
```bash
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -3
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests|Passing|passed|failed" | tail -4
```
Expected: ~33 tests pass; no load errors.

- [ ] **Step 4: Commit**
```bash
git add scripts/view/board_renderer.gd
git commit -m "feat: play vs SimpleAI (human Black, AI White)"
```

---

## Task 4: Visual verify + finalize

- [ ] **Step 1: Visual verification** (controller launches via godot-mcp; user plays)
- The HUD shows "Turn: Black · Captures — Black 0 / White 0".
- Click to place a Black stone; the AI (White) immediately answers with a move.
- Capture White stones; the Black count rises. The AI tries to capture your stones too.
- First to **3 captures** → HUD shows "<color> wins! (提3子) … press R to restart".
- Press **R** → board clears, counts reset, you can play again.
- Ko/suicide still rejected; normal captures still work.

- [ ] **Step 2: Record the design decision in the spec**

In `docs/superpowers/specs/2026-06-01-mini-go-design.md`:
- §1 Overview: note that the 9×9 v1 win condition is **capture 3 stones (提3子) vs a simple AI**; full territory scoring is deferred to the 19×19 expansion.
- §11: replace the M4 line with:
  `4. **M4 — Capture-race vs AI:** ✅ DONE — SimpleAI (capture-greedy) opponent, first to 3 captures wins, HUD + restart. (Full territory scoring deferred to 19×19 — see §14.)`
- §14 Future roadmap: add "Full territory/area scoring + dead-stone marking (arrives with the 19×19 expansion)" and "Smarter AI (beyond capture-greedy)".

- [ ] **Step 3: Commit & push**
```bash
git add docs/superpowers/specs/2026-06-01-mini-go-design.md
git commit -m "docs: 9x9 v1 win = capture 3 vs AI; defer full scoring to 19x19"
git push origin main
```

---

## Done criteria

- `SimpleAI` unit-tested (legal moves only, takes/prefers captures) — ~33 tests green.
- In-game: you (Black) play vs the AI (White); first to 3 captures wins; R restarts; HUD shows state.
- Ko/suicide still enforced; input state never mutated.
- Committed and pushed.

## Out of scope (future)

- Full territory/area scoring, passing, dead-stone marking (deferred to 19×19 expansion).
- Stronger AI (reading ahead, life-and-death). Capture-greedy is intentionally simple.
- Choosing your color / board size, difficulty levels.

# Mini Go — Milestone 3: Legality (Ko + Suicide) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make illegal moves actually illegal — forbid **suicide** (playing a stone that leaves your own group with zero liberties and captures nothing) and **ko / 打劫** (playing a move that recreates the board position from immediately before your opponent's last move). Illegal clicks are simply ignored in-game.

**Architecture:** Extend the pure logic. `BoardState` gains an `equals()` so positions can be compared (needed for ko). `GoRules.place()` gains an optional `ko_forbidden` previous-position argument and now returns a legality verdict `{ ok, reason, state, captured }`: it rejects suicide (after resolving captures, the placed group has 0 liberties) and ko (result equals `ko_forbidden`). The renderer tracks the board position before the last move and passes it as `ko_forbidden`, ignoring rejected moves. All logic stays unit-tested.

**Tech Stack:** Godot 4.4.1, GDScript, GUT (headless).

**Reference spec:** `docs/superpowers/specs/2026-06-01-mini-go-design.md` (§3, §4).

**Conventions:**
- `GODOT` = `/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot`
- Test command: `$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- If a `class_name` isn't found on a fresh run, run `$GODOT --headless --path . --import` once, then re-run.
- From `/Users/jxn/dev/fun_side_proj/go`. Commit per task; do NOT push (controller pushes).

---

## Rules background (for the implementer)

- **Suicide:** After placing your stone AND removing any enemy groups it captures, if YOUR OWN group at that point has zero liberties, the move is illegal. (A move that captures enemy stones is never suicide, because the capture frees liberties — so always resolve captures first, then check your own group.)
- **Ko (打劫):** You may not play a move whose resulting board position is identical to the position that existed immediately before your opponent's last move. In practice this stops the instant back-and-forth recapture of a single stone. We implement basic ko by remembering the single previous position and forbidding its recreation.

---

## File Structure (M3)

- Modify `scripts/model/board_state.gd` — add `equals(other) -> bool`.
- Modify `tests/test_board_state.gd` — add equals tests.
- Modify `scripts/model/go_rules.gd` — add suicide + ko; new return shape `{ok, reason, state, captured}`.
- Modify `tests/test_go_rules.gd` — add suicide + ko tests; existing tests updated to read the new shape.
- Modify `scripts/view/board_renderer.gd` — track previous position, pass `ko_forbidden`, ignore illegal moves.

---

## Task 1: BoardState.equals — TDD

**Files:** Modify `scripts/model/board_state.gd`, `tests/test_board_state.gd`

- [ ] **Step 1: Add failing tests** — Append to `tests/test_board_state.gd`:
```gdscript
func test_equals_true_for_identical_boards() -> void:
	var a := BoardState.empty().with_point(3, 3, BoardState.Point.BLACK)
	var b := BoardState.empty().with_point(3, 3, BoardState.Point.BLACK)
	assert_true(a.equals(b))

func test_equals_false_for_different_boards() -> void:
	var a := BoardState.empty().with_point(3, 3, BoardState.Point.BLACK)
	var b := BoardState.empty().with_point(3, 3, BoardState.Point.WHITE)
	assert_false(a.equals(b))

func test_equals_true_for_two_empty_boards() -> void:
	assert_true(BoardState.empty().equals(BoardState.empty()))
```

- [ ] **Step 2: Run — expect FAIL** (`equals` not found). Run the test command.

- [ ] **Step 3: Implement** — Add this method to `scripts/model/board_state.gd` (e.g. after `with_point`):
```gdscript
## True if `other` has the exact same stones in the same places.
func equals(other: BoardState) -> bool:
	return _cells == other._cells
```

- [ ] **Step 4: Run — expect PASS** (3 new tests; 25 total).

- [ ] **Step 5: Commit**
```bash
git add scripts/model/board_state.gd tests/test_board_state.gd
git commit -m "feat: BoardState.equals for position comparison (TDD)"
```

---

## Task 2: GoRules suicide + ko — TDD

**Files:** Modify `scripts/model/go_rules.gd`, `tests/test_go_rules.gd`

**IMPORTANT — return shape change:** `place()` now returns
`{ "ok": bool, "reason": String, "state": BoardState, "captured": Array }`.
For a legal move `ok=true`, `reason=""`, and `state`/`captured` are as before. For an illegal
move `ok=false`, `reason` is `"suicide"` or `"ko"`, `state` is the UNCHANGED input state, and
`captured=[]`. The existing M2 tests must be updated to assert `result["ok"] == true` where
relevant (they already read `state`/`captured`, which still work).

- [ ] **Step 1: Update existing tests + add failing tests** — In `tests/test_go_rules.gd`, the
existing tests keep working (state/captured unchanged for legal moves). Append these new tests:
```gdscript
func test_suicide_is_illegal() -> void:
	# Black plays into a point fully surrounded by White, capturing nothing.
	var s := _b()
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(2, 1, WHITE)
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(1, 2, WHITE)
	var result := GoRules.place(s, 1, 1, BLACK)
	assert_false(result["ok"], "filling your own last liberty with no capture is suicide")
	assert_eq(result["reason"], "suicide")
	# state unchanged: (1,1) still empty
	var state: BoardState = result["state"]
	assert_eq(state.get_point(1, 1), EMPTY)

func test_capturing_move_that_would_be_suicide_is_legal() -> void:
	# Black (0,0) would be surrounded, but it captures White (1,0) first, gaining a liberty.
	# White (1,0) has its only liberty at (0,0); White (0,1) survives via (0,2).
	var s := _b()
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(1, 1, BLACK)
	var result := GoRules.place(s, 0, 0, BLACK)
	assert_true(result["ok"], "capturing frees a liberty, so not suicide")
	assert_true(result["captured"].has(Vector2i(1, 0)))

func test_ko_recapture_is_illegal_and_legal_without_ko_guard() -> void:
	# Canonical ko around point (2,1):
	#   col: 0 1 2 3
	# row0:  . B W .
	# row1:  B W . W
	# row2:  . B W .
	var a := _b()
	a = a.with_point(1, 0, BLACK)
	a = a.with_point(0, 1, BLACK)
	a = a.with_point(1, 2, BLACK)
	a = a.with_point(1, 1, WHITE)
	a = a.with_point(2, 0, WHITE)
	a = a.with_point(3, 1, WHITE)
	a = a.with_point(2, 2, WHITE)
	# Black captures the White stone at (1,1) by playing (2,1) -> position B.
	var black_move := GoRules.place(a, 2, 1, BLACK)
	assert_true(black_move["ok"])
	assert_true(black_move["captured"].has(Vector2i(1, 1)))
	var b: BoardState = black_move["state"]
	# White recaptures at (1,1): without ko guard this is legal...
	var no_guard := GoRules.place(b, 1, 1, WHITE)
	assert_true(no_guard["ok"])
	# ...but with ko_forbidden = a (the position before Black's move), it's illegal.
	var with_guard := GoRules.place(b, 1, 1, WHITE, a)
	assert_false(with_guard["ok"], "immediate recapture recreates the prior position")
	assert_eq(with_guard["reason"], "ko")

func test_legal_move_reports_ok_true() -> void:
	var result := GoRules.place(_b(), 4, 4, BLACK)
	assert_true(result["ok"])
	assert_eq(result["reason"], "")
```

Also, in the FOUR existing M2 tests that place legal moves, add an `assert_true(result["ok"])`
line where natural (optional but recommended). They will pass regardless since the shape is
backward-compatible for `state`/`captured`.

- [ ] **Step 2: Run — expect FAIL** (new asserts fail; `place` has no `ok`/`reason`/ko param).

- [ ] **Step 3: Implement** — Replace the body of `scripts/model/go_rules.gd` with:
```gdscript
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
```

- [ ] **Step 4: Run — expect PASS** (all tests; ~29 total). Run `--import` first if class cache complains.

- [ ] **Step 5: Commit**
```bash
git add scripts/model/go_rules.gd tests/test_go_rules.gd
git commit -m "feat: GoRules suicide + ko legality with verdict result (TDD)"
```

---

## Task 3: Wire legality into the renderer

**Files:** Modify `scripts/view/board_renderer.gd`

The renderer must remember the position **before the last move** and pass it as `ko_forbidden`,
and must ignore moves the rules reject.

- [ ] **Step 1: Add a field for the previous position**

In `scripts/view/board_renderer.gd`, near the other `var` declarations (after `var _current_color...`), add:
```gdscript
# The board position just before the last applied move — what a ko recapture
# would illegally recreate. Null until the first move is made.
var _prev_state: BoardState = null
```

- [ ] **Step 2: Replace `_try_place` to enforce legality and track history**

Replace the entire `_try_place` function with:
```gdscript
func _try_place(x: int, y: int) -> void:
	if not _state.in_bounds(x, y):
		return
	if not _state.is_empty(x, y):
		return
	var result := GoRules.place(_state, x, y, _current_color, _prev_state)
	if not result["ok"]:
		return  # illegal (suicide or ko) — ignore the click
	var position_before_move := _state
	_state = result["state"]
	_add_stone_sprite(x, y, _current_color)
	for captured in result["captured"]:
		_remove_stone_sprite(captured.x, captured.y)
	_prev_state = position_before_move
	_current_color = BoardState.Point.WHITE if _current_color == BoardState.Point.BLACK else BoardState.Point.BLACK
```

- [ ] **Step 3: Verify project loads + all tests pass**
```bash
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -3
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests|Passing|passed|failed" | tail -4
```
Expected: ~29 tests, all passing; no load errors.

- [ ] **Step 4: Commit**
```bash
git add scripts/view/board_renderer.gd
git commit -m "feat: enforce ko + suicide in the renderer (ignore illegal clicks)"
```

---

## Task 4: Visual verify + finalize

- [ ] **Step 1: Visual verification** (controller launches via godot-mcp; user tests)
- Suicide: surround an empty point with the OTHER color, then try to play your stone into it → the click should do nothing (no stone placed).
- Ko: create a ko shape, capture the single stone, then immediately try to recapture → the click should do nothing. Play elsewhere, and the recapture becomes legal again on a later turn.

- [ ] **Step 2: Mark M3 done in spec** — In `docs/superpowers/specs/2026-06-01-mini-go-design.md` §11:
```
3. **M3 — Legality:** ✅ DONE — ko + suicide prevention in GoRules (verdict result), enforced in renderer.
```

- [ ] **Step 3: Commit & push**
```bash
git add docs/superpowers/specs/2026-06-01-mini-go-design.md
git commit -m "docs: mark Milestone 3 (legality) complete"
git push origin main
```

---

## Done criteria for M3

- `BoardState.equals`, suicide, and ko are unit-tested (≈29 tests green).
- In-game: suicide moves and immediate ko recaptures are silently rejected; everything else still works (placing, capturing).
- Input state never mutated.
- Committed and pushed.

## Out of scope (Milestone 4)

- Passing, two-consecutive-passes ending the game, dead-stone marking, area scoring + komi, winner.
- Positional superko (we implement basic single-step ko, which is the standard and prevents the simple infinite recapture). Note: rare multi-step repetitions (e.g. triple ko) are not handled — acceptable for v1.

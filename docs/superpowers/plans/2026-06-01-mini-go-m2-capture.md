# Mini Go — Milestone 2: Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Go's capture rule — when a group of stones has no liberties (no empty adjacent points), it is removed from the board — and wire it into the game so captured stones visually disappear.

**Architecture:** Two new pure-logic files in `scripts/model/` (no Godot deps): `GroupAnalysis` (find a stone's connected group + count its liberties via flood fill) and `GoRules` (place a stone, then capture any adjacent enemy group reduced to zero liberties). Both are unit-tested with GUT. The renderer is then changed to route clicks through `GoRules.place()` and remove the sprites of captured stones. Ko and suicide are explicitly OUT of scope (Milestone 3).

**Tech Stack:** Godot 4.4.1, GDScript, GUT (headless).

**Reference spec:** `docs/superpowers/specs/2026-06-01-mini-go-design.md` (§3 model, §11 milestones).

**Conventions:**
- `GODOT` = `/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot`
- Test command: `$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- If Godot can't find a `class_name` on a fresh run, run `$GODOT --headless --path . --import` once first, then re-run tests.
- All commands run from `/Users/jxn/dev/fun_side_proj/go`. Commit per task; do NOT push (controller pushes).

---

## Background: the capture rule (for the implementer)

- Stones connect into a **group** if they are the same color and orthogonally adjacent (up/down/left/right — NOT diagonal).
- A group's **liberties** are the distinct EMPTY points orthogonally adjacent to any stone in the group.
- When you place a stone, **first** remove any *enemy* group that now has 0 liberties (these are captured). The just-placed stone's own suicide is handled later (M3), so for M2 we only ever remove enemy groups.
- Capture is checked only for groups adjacent to the just-placed stone (only those can lose their last liberty from this move).

---

## File Structure (M2)

- Create `scripts/model/group_analysis.gd` — `group_at()` + `count_liberties()` (flood fill).
- Create `tests/test_group_analysis.gd` — unit tests.
- Create `scripts/model/go_rules.gd` — `place()` returns new state + captured list.
- Create `tests/test_go_rules.gd` — capture-scenario unit tests.
- Modify `scripts/view/board_renderer.gd` — route clicks through `GoRules.place()`, remove captured sprites.

---

## Task 1: GroupAnalysis (flood fill + liberties) — TDD

**Files:**
- Create: `scripts/model/group_analysis.gd`
- Test: `tests/test_group_analysis.gd`

- [ ] **Step 1: Write the failing test** — Create `tests/test_group_analysis.gd`:
```gdscript
extends GutTest

func _b() -> BoardState:
	return BoardState.empty()

func test_group_at_empty_point_is_empty_array() -> void:
	assert_eq(GroupAnalysis.group_at(_b(), 4, 4), [])

func test_group_at_single_stone() -> void:
	var s := _b().with_point(4, 4, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.group_at(s, 4, 4), [Vector2i(4, 4)])

func test_group_at_connected_line_of_three() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 0, BoardState.Point.BLACK)
	s = s.with_point(2, 0, BoardState.Point.BLACK)
	var group := GroupAnalysis.group_at(s, 0, 0)
	assert_eq(group.size(), 3)
	assert_true(group.has(Vector2i(0, 0)))
	assert_true(group.has(Vector2i(1, 0)))
	assert_true(group.has(Vector2i(2, 0)))

func test_group_at_ignores_diagonal_and_other_color() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 1, BoardState.Point.BLACK) # diagonal — NOT connected
	s = s.with_point(1, 0, BoardState.Point.WHITE) # adjacent but other color
	assert_eq(GroupAnalysis.group_at(s, 0, 0), [Vector2i(0, 0)])

func test_liberties_single_stone_center_is_four() -> void:
	var s := _b().with_point(4, 4, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 4, 4)), 4)

func test_liberties_single_stone_corner_is_two() -> void:
	var s := _b().with_point(0, 0, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 2)

func test_liberties_reduced_by_adjacent_enemy() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 0, BoardState.Point.WHITE) # takes one of black's two corner liberties
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 1)

func test_liberties_are_deduped_across_group() -> void:
	# Two black stones stacked vertically in the corner column share no double-counts.
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(0, 1, BoardState.Point.BLACK)
	# Liberties: (1,0), (1,1), (0,2) = 3 distinct empty neighbors.
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 3)
```

- [ ] **Step 2: Run to verify it fails**

Run the test command. Expected: FAIL — `GroupAnalysis` not declared.

- [ ] **Step 3: Implement** — Create `scripts/model/group_analysis.gd`:
```gdscript
## Pure board analysis: connected groups and their liberties. No Godot deps.
class_name GroupAnalysis
extends RefCounted

# Orthogonal neighbor offsets (Go connects up/down/left/right, never diagonally).
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## All coords in the connected same-color group containing (x, y).
## Returns [] if (x, y) is empty. (Flood fill.)
static func group_at(state: BoardState, x: int, y: int) -> Array:
	var color := state.get_point(x, y)
	if color == BoardState.Point.EMPTY:
		return []
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	var group: Array = []
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		group.append(p)
		for d in NEIGHBORS:
			var n := p + d
			if state.in_bounds(n.x, n.y) and not seen.has(n) \
					and state.get_point(n.x, n.y) == color:
				stack.append(n)
	return group

## Count of distinct EMPTY points orthogonally adjacent to the group.
static func count_liberties(state: BoardState, group: Array) -> int:
	var libs := {}
	for p in group:
		for d in NEIGHBORS:
			var n: Vector2i = p + d
			if state.in_bounds(n.x, n.y) \
					and state.get_point(n.x, n.y) == BoardState.Point.EMPTY:
				libs[n] = true
	return libs.size()
```

- [ ] **Step 4: Run to verify it passes**

Run the test command. Expected: PASS — 8 new tests pass (16 total with prior milestones).

- [ ] **Step 5: Commit**
```bash
git add scripts/model/group_analysis.gd tests/test_group_analysis.gd
git commit -m "feat: GroupAnalysis — connected groups + liberty counting (TDD)"
```

---

## Task 2: GoRules.place with capture — TDD

**Files:**
- Create: `scripts/model/go_rules.gd`
- Test: `tests/test_go_rules.gd`

- [ ] **Step 1: Write the failing test** — Create `tests/test_go_rules.gd`:
```gdscript
extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE
const EMPTY := BoardState.Point.EMPTY

func _b() -> BoardState:
	return BoardState.empty()

func test_place_with_no_capture_sets_stone_and_empty_captures() -> void:
	var result := GoRules.place(_b(), 4, 4, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(4, 4), BLACK)
	assert_eq(result["captured"], [])

func test_place_does_not_mutate_input_state() -> void:
	var start := _b()
	var _r := GoRules.place(start, 4, 4, BLACK)
	assert_eq(start.get_point(4, 4), EMPTY, "input state must be unchanged")

func test_captures_single_stone_in_corner() -> void:
	# White at (0,0). Black already at (1,0). Black plays (0,1) -> white has 0 liberties.
	var s := _b()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var result := GoRules.place(s, 0, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), EMPTY, "captured white stone is removed")
	assert_eq(state.get_point(0, 1), BLACK, "the placed black stone stays")
	assert_true(result["captured"].has(Vector2i(0, 0)))
	assert_eq(result["captured"].size(), 1)

func test_no_capture_when_group_still_has_a_liberty() -> void:
	# White at (0,0) with liberties (1,0) and (0,1). Black plays only (1,0).
	var s := _b().with_point(0, 0, WHITE)
	var result := GoRules.place(s, 1, 0, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), WHITE, "white still has liberty (0,1), not captured")
	assert_eq(result["captured"], [])

func test_captures_a_multi_stone_group() -> void:
	# White group (0,0)+(1,0). Black surrounds: (2,0),(0,1),(1,1) already; play last lib.
	# Liberties of the white pair are (2,0),(0,1),(1,1). Fill first two, then play (1,1).
	var s := _b()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(0, 1, BLACK)
	var result := GoRules.place(s, 1, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), EMPTY)
	assert_eq(state.get_point(1, 0), EMPTY)
	assert_eq(result["captured"].size(), 2)
	assert_true(result["captured"].has(Vector2i(0, 0)))
	assert_true(result["captured"].has(Vector2i(1, 0)))

func test_captures_two_separate_groups_with_one_move() -> void:
	# Two separate single white stones, each on their last liberty, both adjacent
	# to the move at (1,1): white at (1,0) and (0,1).
	# white (1,0) neighbors: (0,0),(2,0),(1,1). white (0,1) neighbors: (0,0),(0,2),(1,1).
	# Fill all their other liberties with black, then play (1,1).
	var s := _b()
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(0, 0, BLACK)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(0, 2, BLACK)
	var result := GoRules.place(s, 1, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(1, 0), EMPTY)
	assert_eq(state.get_point(0, 1), EMPTY)
	assert_eq(result["captured"].size(), 2)
```

- [ ] **Step 2: Run to verify it fails**

Run the test command. Expected: FAIL — `GoRules` not declared.

- [ ] **Step 3: Implement** — Create `scripts/model/go_rules.gd`:
```gdscript
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
```

- [ ] **Step 4: Run to verify it passes**

Run the test command. Expected: PASS — 6 new tests pass (22 total).

- [ ] **Step 5: Commit**
```bash
git add scripts/model/go_rules.gd tests/test_go_rules.gd
git commit -m "feat: GoRules.place with enemy-group capture (TDD)"
```

---

## Task 3: Wire capture into the renderer + visual verify

**Files:**
- Modify: `scripts/view/board_renderer.gd`

- [ ] **Step 1: Update `_try_place` to route through GoRules and remove captured sprites**

In `scripts/view/board_renderer.gd`, replace the existing `_try_place` function:
```gdscript
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
```
(Everything else in the file stays the same. `_add_stone_sprite` and `_remove_stone_sprite` already exist.)

- [ ] **Step 2: Verify the whole project still loads and tests still pass**

Run:
```bash
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -3
/Users/jxn/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests|Passing|passed|failed" | tail -5
```
Expected: 22 tests, all passing. No load errors.

- [ ] **Step 3: Visual verification (controller launches via godot-mcp; ask the user to test)**

Launch via godot-mcp `run_project`, confirm no errors via `get_debug_output`. Then verify the capture works in-game by setting up a simple capture:
- Place a White stone somewhere (e.g. a corner).
- Surround it with Black stones on all its liberties.
- When the last liberty is filled by Black, **the White stone should vanish**.
Confirm captured stones disappear and the surrounding stones remain. Stop via `stop_project`.

- [ ] **Step 4: Commit**
```bash
git add scripts/view/board_renderer.gd
git commit -m "feat: remove captured stones in the renderer via GoRules"
```

---

## Task 4: Finalize M2

- [ ] **Step 1: Mark M2 done in the spec**

In `docs/superpowers/specs/2026-06-01-mini-go-design.md` §11, update line 2:
```
2. **M2 — Capture:** ✅ DONE — liberties + group capture in GroupAnalysis / GoRules, TDD'd, wired into the renderer.
```

- [ ] **Step 2: Commit and push**
```bash
git add docs/superpowers/specs/2026-06-01-mini-go-design.md
git commit -m "docs: mark Milestone 2 (capture) complete"
git push origin main
```

---

## Done criteria for M2

- `GroupAnalysis` and `GoRules` unit tests pass headless (22 total tests green).
- In-game: surrounding an enemy group on its last liberty removes it (stones disappear).
- Input state is never mutated (immutability test passes).
- All work committed and pushed.

## Out of scope (Milestone 3)

- **Ko rule** (no immediate recapture recreating the previous position).
- **Suicide prevention** (playing a stone that would leave your OWN group with 0 liberties and captures nothing → illegal). For now such a move is allowed and will just sit on the board.
- Passing, scoring, dead-stone marking (M4).

# Mini Go (围棋) — Design Spec

**Date:** 2026-06-01
**Status:** Approved design, pre-implementation
**Engine:** Godot 4.4.1 (.stable.official)
**Tooling:** godot-mcp connected (scaffold scenes, run, capture output); Aseprite for pixel art

---

## 1. Overview

A small, playable game of **Go / Weiqi (围棋)** on a **9×9 board** (81 line intersections),
with **full rules** and **two-player hotseat** (two humans, same screen). It doubles as a
hands-on project for learning **pixel-art tilesets** in Godot.

Not Xiangqi (Chinese chess). Stones are placed on line *intersections*; there are no moving pieces.

### Goals
- A correct, complete 9×9 Go game: place, capture, ko, suicide-prevention, scoring, winner.
- A clean separation that makes the rules unit-testable in isolation.
- A pixel-art pipeline the user (a beginner) can drive: draw tiles in Aseprite → export → see them in-game.

### Non-goals (v1) — local hotseat only
- AI opponent (hotseat only; AI is a clean later addition).
- Online / networked multiplayer (deferred — see §14 Future roadmap).
- Web distribution / itch.io build (deferred — see §14).
- Multiple board sizes (9×9 only).
- More than one art theme shipped (Kaya only now; see §8 — designed to swap, others added later).

---

## 2. Core principle: logic and rendering are fully separate

The **rules of Go live in plain GDScript with zero Godot nodes** — a pure board model testable
without opening a window. The visual layer (TileMapLayers) only *reflects* that model.
A bug is therefore either "the rules are wrong" (model tests) or "the drawing is wrong" (visual),
never a tangle of both. This also matches the project's immutability / decoupling style.

---

## 3. The board model (pure, immutable)

Located in `scripts/model/` — no Godot scene dependencies.

- **`BoardState`** — a 9×9 grid; each point is `EMPTY / BLACK / WHITE`.
  **Immutable**: placing a stone returns a *new* `BoardState`, never mutates the existing one.
  (Immutability makes the ko rule trivial — positions can be compared/hashed directly.)
- **`GroupAnalysis`** — flood-fill from a stone to find its connected group (same color, orthogonally
  adjacent) and count its **liberties** (empty adjacent points). The heart of capture logic.
- **`GoRules`** — `try_place(state, x, y, color)` returns either `{ new_state, captured_stones }`
  or a typed rejection reason. Enforced order:
  1. Target point empty? (else illegal)
  2. Place the stone (into a new state).
  3. Remove any **opponent** groups now at 0 liberties → these are **captures**.
  4. Is the **placed stone's own** group now at 0 liberties? → **suicide → illegal** (revert).
  5. Does the resulting position recreate the **immediately previous** board position? → **ko → illegal**.
- **`Move`** (forward-compatible decision) — a turn is represented as a small, **serializable action**:
  `place(x, y)` or `pass`. The controller advances state by applying a `Move`. This costs nothing
  now but is exactly what **networking** (send moves over the wire), **replay/undo**, and **SGF
  export** later all require. Keep the model driven by applying `Move`s, never by ad-hoc UI calls.
- **`Scoring`** — **area scoring (Chinese rules)**:
  `score(color) = (color's stones on board) + (empty territory surrounded only by that color)`,
  **+ komi for White** (default **7**, configurable). Empty regions touching both colors are neutral (dame).
  Higher score wins.

### Coordinates
Grid coords are `(x, y)` with `0..8` each. Conversion to/from screen pixels is the renderer's job
via `TileMapLayer.local_to_map()` / `map_to_local()`. The model never deals in pixels.

---

## 4. Game flow & the "hard part" (end + dead stones)

A Go engine cannot reliably know which stones are "dead" at game end, so we use the standard
digital-Go flow, owned by `GameController`:

- **Phase: Playing** — players alternate (Black first). A turn is either *place a legal stone* or *pass*.
- **Two consecutive passes → Phase: MarkDead.** Players click groups to toggle them dead/alive.
  Dead groups are removed from the board and added to the capturer's prisoners.
- **Confirm → Phase: GameOver.** Compute area score + komi, declare winner, show result.

`GameController` (a Node) holds the current `BoardState`, current player, prisoner counts, pass
counter, and phase. It emits signals on every change; the view and HUD subscribe. It owns the
*previous* board position for the ko check.

---

## 5. Rendering & the tileset

`scripts/view/` + scenes. Two stacked `TileMapLayer`s sharing **one** `TileSet`:

- **Board layer** (bottom) — built once from the board tiles. Static.
- **Stone layer** (top) — `set_cell(coord, black|white)` to place; clear the cell to capture.
  Stones use the transparent tiles, so the board shows through around them.

- **Input** (`input_handler.gd`) — mouse → grid coord via `local_to_map()`; a faint **ghost stone**
  previews the hovered intersection; click emits `intersection_clicked(x, y)` to the controller.
- **ThemeManager** (`scripts/theme/`) — designed so a theme = one TileSet resource; swapping is a
  single call. v1 ships **Kaya** only; the switcher UI is deferred.

### Default texture filter
Project default texture filter set to **Nearest** (no bilinear) so pixel art stays crisp. This is
the #1 pixel-art gotcha and is set project-wide.

---

## 6. Asset / tileset specification

**Current asset:** `assets/themes/kaya/go-board.png` — **96 × 128 px, RGBA**. One image, twelve 32×32 tiles.
Both TileMapLayers share a single `TileSet` atlas built from this image.

### Tile layout (atlas coords, col,row; 32px cells)
```
row 0 (y 0–32):   (0,0) top-left corner   (1,0) top edge        (2,0) top-right corner
row 1 (y 32–64):  (0,1) left edge          (1,1) center cross ┼  (2,1) right edge
row 2 (y 64–96):  (0,2) bottom-left corner (1,2) bottom edge     (2,2) bottom-right corner
row 3 (y 96–128): (0,3) star point (星)    (1,3) WHITE stone     (2,3) BLACK stone
```
- Board tiles (rows 0–2 + star) are **opaque** (wood background baked in).
- Stone tiles (white, black) are **transparent** outside the circle.
- **Note:** stone order in the file is white-then-black; the Godot TileSet mapping matches the file.

### The alignment rule (seamless board)
Every line sits on the **same center pixels** in each tile: verticals at **x = 15, 47, 79**,
horizontals at **y = 15, 47, 79** (32px apart, pixel 15–16 of each cell). Bulletproof method:
draw the center-cross tile once, copy into all 9 board cells, then **erase the arms** not needed
on corners/edges. Guarantees lines meet across seams.

### On-screen size
Board = 9 × 32 = **288 × 288 px**, scaled up by the camera/window for a chunky pixel look.

---

## 7. Aseprite → Godot pipeline (beginner guide)

**Canvas:** 96 × 128, RGB color mode. Grid 32×32 (View → Grid → Grid Settings; Show Grid on).
Pencil 1px, Pixel-Perfect on. Board and stones may live on **separate Aseprite layers** (good for
organization); they flatten correctly on export.

**Drawing:**
- *Board tiles:* fill wood background, draw lines through cell centers (see alignment rule). Opaque.
- *Star point:* center cross + small ~4px center dot.
- *Stones:* on the stone layer, **leave background transparent** (checkerboard), draw only the
  filled circle (Ellipse tool, ~26px). Optional 2–3 lighter pixels top-left for a shine.

**Export (one PNG):** File → Export As → `go-board.png`, **Scale 100%** (never upscale),
all layers visible, "Selected layers only" off (so they merge, preserving stone transparency).

**Into Godot:** save under `res://assets/themes/kaya/`. Godot auto-imports; filter = Nearest.
TileSet = add texture as Atlas source → tile size 32×32 → auto-generate tiles. Board layer uses
tiles 1–10, stone layer uses the two stone tiles.

**Iteration loop forever after:** draw → Export As `go-board.png` (overwrite) → Godot updates live.

---

## 8. Theme palettes (Kaya now; others later)

Each theme = ~5 colors, same 12 tiles recolored. Set as an Aseprite palette; recolor = swap palette
entries. v1 ships **Kaya**; Dusk and Paper are recorded here for when we add them.

| Role          | Classic Kaya | Pixel Dusk | Soft Paper |
|---------------|--------------|------------|------------|
| Background    | `#E3B873`    | `#2E2B3F`  | `#F2EAD8`  |
| Line + star   | `#4A3A28`    | `#6B6488`  | `#5A5246`  |
| Black stone   | `#1A1A1A`    | `#14121C`  | `#2B2824`  |
| Black shine   | `#5A5A5A`    | `#4A4660`  | `#6A655C`  |
| White stone   | `#F5F2EA`    | `#D8D2EA`  | `#FBFAF6`  |
| White outline | `#B0A890`    | `#9A93B8`  | `#5A5246`  |

---

## 9. File layout (many small files)

```
scripts/model/    board_state.gd, group_analysis.gd, go_rules.gd, scoring.gd   ← pure, testable
scripts/game/     game_controller.gd     ← turns, captures, pass/end, phases, ko history
scripts/view/     board_renderer.gd, input_handler.gd
scripts/ui/       hud.gd                 ← turn indicator, prisoner counts, Pass button, result
scripts/theme/    theme_manager.gd       ← TileSet-per-theme (Kaya only shipped)
scenes/           main.tscn, board.tscn, hud.tscn
assets/themes/    kaya/go-board.png  (pixel-dusk/, soft-paper/ reserved for later)
tests/            unit tests for the model (GUT)
```

---

## 10. Testing

The pure model is ideal for TDD. Use **GUT (Godot Unit Test)**. Write tests *first* for the model
layer, targeting the 80% bar:
- Capture: single stone, multi-stone group, multiple groups captured by one move, edge/corner groups.
- Suicide: illegal self-capture; legal move that fills own last liberty *because* it captures.
- Ko: immediate recapture illegal; legal again after an intervening move elsewhere.
- Scoring: simple territory, neutral (dame) regions, komi applied to White, winner determination.

View/UI verified by running the game via godot-mcp and observing behavior.

---

## 11. Build order (milestones)

1. **M1 — It's alive:** ✅ **DONE (2026-06-01)** — project setup (texture filter, TileSet from
   `go-board.png`), board renders in Kaya, click places alternating stones (no rules yet).
   `BoardState` + `TilesetBuilder` unit-tested (6/6 GUT). Render/run loop confirmed end-to-end.
2. **M2 — Capture:** ✅ **DONE (2026-06-01)** — liberties + group capture in `GroupAnalysis` /
   `GoRules` (22/22 GUT), wired into the renderer (captured stones disappear).
3. **M3 — Legality:** ko + suicide prevention.
4. **M4 — Endgame:** pass → two-pass end → dead-stone marking → area scoring + komi → winner display.
5. **M5 — Polish:** ghost-stone preview, prisoner-count HUD, result screen. (Theme switcher deferred
   until a second theme exists.)
6. **Art track (parallel):** refine the Kaya tileset in Aseprite; add Dusk/Paper themes later.

---

## 12. Resolved decisions

- Game: Go/Weiqi, 9×9, full rules, 2-player hotseat.
- Scoring: **area / Chinese**, komi **7** (configurable).
- Rendering: pure immutable model + two shared-TileSet `TileMapLayer`s (board + stones).
- Tile size: **32×32**; board 288×288 scaled up.
- Default theme: **Kaya** (only theme shipped in v1; architecture supports swapping).
- Pixel tool: Aseprite; asset at `assets/themes/kaya/go-board.png` (96×128 RGBA).
- Placeholder-first art workflow: mechanics built against the current art; art refined in parallel.

---

## 13. Notes / open items

- **Git:** initialized; `origin` = `git@github.com:jxnhoongz/weiqi-gd.git`, pushed. Commit per milestone.
- **Tileset alignment:** current `go-board.png` line spacing is close but may be off by ~1px between
  cells; acceptable for M1, refine during the art track.

## 14. Future roadmap (post-v1, not built now)

Recorded so v1 decisions stay compatible. None of this is implemented in v1.

- **Online multiplayer (play with friends).** Two humans, different machines. Godot's high-level
  multiplayer API (ENet) or a lightweight relay. Enabled cheaply by the `Move`-driven model (§3):
  the authoritative side applies `Move`s and broadcasts them; clients replay the same `Move`s.
  Likely approach: host/join via room code, or a small relay server. Turn-based Go is forgiving of
  latency, so this is very achievable.
- **itch.io distribution.** Godot exports to **HTML5/WebAssembly**, which itch.io hosts directly
  (upload the export as a "HTML5 playable" zip). Keep rendering web-export-friendly (it already is —
  2D TileMaps export cleanly). Desktop exports (mac/win/linux) are also one-click if wanted.
- **Other niceties** unlocked by the same foundations: AI opponent, move history / undo,
  **SGF import-export** (standard Go game format), more board sizes (13×13 / 19×19), theme switcher
  (Dusk/Paper), sound.

Sequencing intent: finish v1 local hotseat → add SGF/replay (proves the `Move` model) →
online multiplayer → HTML5 export to itch.

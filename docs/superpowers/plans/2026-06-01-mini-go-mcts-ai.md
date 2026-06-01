# Mini Go — MCTS AI (capture-race) Design + Plan

> Implemented in-session with TDD. Records the design so the algorithm is reviewable.

**Goal:** Replace the one-move `SimpleAI` with a **Monte Carlo Tree Search** opponent that searches
ahead and plays toward the actual win condition (first to capture 3 stones, 提3子). Pure GDScript,
no external dependencies, safe for HTML5/itch export.

**Why MCTS (not an external engine):** KataGo/Pachi/GnuGo are native binaries that can't run in a
web build and optimize *territory*, not our capture-race. MCTS is an algorithm we can write in
GDScript and point at *our* win condition.

## How MCTS works (the loop, repeated N times per move)
1. **Select** — from the root, descend the tree by UCB1 until reaching a node with untried moves or a terminal position.
2. **Expand** — add one child for an untried legal move.
3. **Simulate (rollout)** — from that child, play (random, legality-checked) moves until someone reaches 3 captures or a depth cap; the winner is the rollout result (depth cap → whoever has more captures; tie → draw).
4. **Backpropagate** — walk back up, incrementing visits and crediting wins to the player who moved into each node.

After N iterations, play the root child with the **most visits**.

## Position model (inside `MctsAI`)
A position = `{ state: BoardState, to_move, cap_black, cap_white, ko }`. Applying a move uses
`GoRules.place(state, x, y, to_move, ko)` (gives the new state + captured list); the mover's capture
count increases by `captured.size()`; the new `ko` (forbidden recreate) becomes the pre-move state —
identical to how the renderer tracks `_prev_state`. Terminal when a capture count ≥ 3, or no legal move.

## Tuning (performance)
GDScript is interpreted, so we cap work: `DEFAULT_ITERATIONS` and `MAX_ROLLOUT_DEPTH`. Rollout moves
use **rejection sampling** (try random empty points until a legal one) to avoid enumerating all 81
points each step. Tune iterations so a move takes a fraction of a second. Threading can come later;
v1 runs synchronously (a brief pause after your move is fine for turn-based play).

## Files
- Create `scripts/ai/mcts_ai.gd` — `MctsAI.choose_move(state, color, cap_black, cap_white, ko, iterations)`.
- Create `tests/test_mcts_ai.gd` — legal-move, no-move, and the key **immediate-win** correctness test.
- Modify `scripts/view/board_renderer.gd` — `_ai_turn()` calls `MctsAI` with the live capture counts.
- `SimpleAI` is kept (used nowhere after wiring, but harmless / handy reference; may remove later).

## Key correctness test
If the AI already has 2 captures and exactly one move captures a stone (reaching 3), MCTS must pick
that move — rollouts from it are guaranteed wins, so it dominates visits. This is the anchor test.

## Out of scope
- Threaded/async search (v1 is synchronous).
- Heuristic-guided rollouts / RAVE / neural priors (possible later strength boosts).
- Territory play (still capture-race until the 19×19 expansion).

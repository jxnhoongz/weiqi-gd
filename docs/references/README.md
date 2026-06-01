# Visual references

Inspiration / north-star screenshots for the look & feel we're aiming at.

## polished-go-app.png  (mobile 围棋 app, captured 2026-06-01)

> **TODO (jxn):** save the phone screenshot here as `polished-go-app.png` so it's
> version-controlled. (Claude can't write the image bytes; drop the file in this folder.)

A highly polished commercial mobile Go app. We use it as a **layout/feature** north star,
NOT necessarily an art-direction match (it's a *realistic* style; our game is pixel-art).

### What's in it (and how hard for us)

**Achievable — layout/UI (our existing Control-node approach):**
- Top opponent bar: avatar + name (电脑 = computer), 提2子 (captured 2), 占83目 (83 points of area)
- Bottom player bar: avatar + name (玩家 = player), 提7子, 占88目
- Board coordinate labels A–S (columns) and 1–19 (rows) on all sides
- Last-move highlight ring (green circle on the most recent stone)
- Bottom action toolbar: 新局 (new game) · 点目 (count) · 形势 (status) · 停一手 (pass) · 悔棋 (undo) · 热度 (heatmap)

**Hard — needs real ART assets (and is a *realistic*, not pixel, style):**
- Illustrated character avatars (player/computer portraits)
- Ink-wash background with mountain/dragon art
- Realistic wood board texture + glossy stones with specular highlights & cast shadows
- Decorative framed score boxes

**Hard — needs a STRONG AI we don't have:**
- 形势 (positional analysis / win estimate)
- 热度 (influence/heat map)

### Takeaway
The structure is very replicable; the *finish* (illustration, realistic rendering, AI analysis)
is an art-and-assets + strong-AI effort. Decide per-feature whether to borrow the **layout** while
keeping our own art style, or to pivot art direction (big commitment).

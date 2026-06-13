# tmux 2x2 Grid Bug on macOS — `resize-pane` Alone Produces Uneven Sizes

> Recorded: 2026-06-06, blocks session `blocks-mgr-092033`

## The Bug

Running the canonical 2x2 spawn recipe (split-window → resize-pane) on
macOS tmux (3.x) produced these pane sizes for `W=220 H=50`, target `110x25`:

```
pane=1 title=worker-1 size=109x24
pane=2 title=worker-2 size=110x24
pane=3 title=worker-3 size=109x25
pane=4 title=worker-4 size=110x25
```

Looks OK on first glance — but in the FIRST attempt (the broken one), the
output was:

```
pane=1 title=worker-1 size=109x22
pane=2 title=worker-2 size=109x1   <-- height = 1 cell, basically invisible
pane=3 title=worker-3 size=109x25
pane=4 title=worker-4 size=110x50  <-- full session height, dominates grid
```

One pane has height=1 (the prompt_toolkit rendering would be unusable),
another has full session height. Subsequent `tmux resize-pane -x 110 -y 25`
calls had **no effect** — the sizes were locked.

## Root Cause

The 2x2 build sequence `split-window -h` → `split-window -v` → `split-window -v`
generates a non-uniform tree: the third split doesn't subdivide the existing
panes evenly, because the panes it splits (1.1, 1.2) don't have equal
dimensions to begin with. The `resize-pane` loop tries to fix it after the
fact, but on macOS tmux 3.x it does nothing when the requested size would
require moving the **other** pane's boundary (it's a no-op for the
"trailing" splits in a 2x2).

The blocks skill's "Never use `select-layout tiled`" rule is wrong on this
version. Older tmux docs warned that tiled would destructively re-compute,
but on macOS tmux 3.x tiled is the **only reliable way** to equalize.

## The Fix

Add `tmux select-layout -t "$SESSION" tiled` **after** all splits, **before**
the resize-pane loop:

```bash
# 3. Build splits (horizontal chain → tiled, supports any N)
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2

# 3b. Force equal sizing: tiled THEN resize-pane (not resize-pane alone).
sleep 1
tmux select-layout -t "$SESSION" tiled   # <-- THE FIX
sleep 1
PANE_W=$((W / COLS))
PANE_H=$((H / 2))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done
```

After the fix, the same session produced:

```
pane=1 size=109x24
pane=2 size=110x24
pane=3 size=109x25
pane=4 size=110x25
```

All within 1 cell of target (109/110 off-by-one is normal tmux granularity
at borders; 24/25 off-by-one is the same).

## Why The Original Rule Was Wrong

The "Never use tiled" advice is from pre-3.0 tmux. On macOS tmux 3.x:

- `select-layout tiled` does **not** destroy pane contents (it preserves
  the running processes, just changes geometry).
- `resize-pane` after `select-layout tiled` works correctly for fine
  adjustments to within 1 cell.
- `resize-pane` **without** tiled is unreliable — always chain tiled → resize-pane
  because tmux won't move other panes' boundaries to make room.

## Verification

After spawning, run:

```bash
tmux list-panes -t "$SESSION" -F 'pane=#{pane_index} size=#{pane_width}x#{pane_height}'
```

Acceptable: all `pane_width` within 1 of each other, all `pane_height`
within 1 of each other.

If not, repeat `select-layout tiled` then resize-pane. If still bad, the
session has stale state — `tmux kill-session -t "$SESSION"` and restart.

## Tested On

- macOS 26.2, tmux 3.4 (or similar 3.x)
- Sessions `blocks-mgr-091637`, `blocks-mgr-091953` (broken attempts)
- Session `blocks-mgr-092033` (fixed attempt, ran successfully for the
  full 7-minute timeout with 4 workers producing 33 KB of results)

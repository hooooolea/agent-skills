Working templates — copy, swap profile names or paths. Base-index 1 assumed (see ../templates/tmux.conf.blocks).

### Recipe: Spawn N Workers in tmux (the only recipe blocks --manager needs)

This is the working template. It only spawns the workers — the Manager is the calling Hermes session, not a tmux pane.

```bash
# N is the number of workers (must be even: 2/4/6/8). Default 4.
N=${BLOCKS_WORKERS:-4}
SESSION="blocks-mgr-$(date +%H%M%S)"
SHARED="$HOME/blocks-shared/$SESSION"

# 1. Create shared directory structure
mkdir -p "$SHARED"/{tasks,results,done}

# 2. Session size: wider for more workers (each worker needs at least 50 cells wide)
W=200
H=50
if [ "$N" -ge 4 ]; then W=220; fi
if [ "$N" -ge 6 ]; then W=300; fi
if [ "$N" -ge 8 ]; then W=380; fi
tmux new-session -d -s "$SESSION" -x $W -y $H

COLS=$((N/2))

# 3. Build N-worker grid: 2 rows × (N/2) cols.
#    Verified split sequence — DO NOT use select-layout tiled (it
#    re-computes the grid destructively). Just split + resize-pane.
#
#    Per-case split sequence (empirically verified, base-index 1):
#      N=2: split-v on 1.1  → 1.1 (top), 1.2 (bottom)
#      N=4: split-h on 1.1, then split-v on each of 1.1 and 1.2
#           → 1.1 TL, 1.2 TR, 1.3 BL, 1.4 BR
#      N=6: as 4, then split-h on 1.2 and split-h on 1.4
#           → adds 1.5 (right of 1.2) and 1.6 (right of 1.4)
#      N=8: as 6, then split-h on 1.5 and split-h on 1.6
#           → adds 1.7 and 1.8
if [ "$N" -eq 2 ]; then
  tmux split-window -v -t "$SESSION":1
elif [ "$N" -eq 4 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
elif [ "$N" -eq 6 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.4
elif [ "$N" -eq 8 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.4
  tmux split-window -h -t "$SESSION":1.5
  tmux split-window -h -t "$SESSION":1.6
fi

# 4. Force equal sizing (resize-pane only, NO select-layout tiled)
PANE_W=$((W / COLS))
PANE_H=$((H / 2))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

# 5. Tag panes as worker-1..worker-N (left-to-right, top-to-bottom)
i=1
for p in $ALL_PANES; do
  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
  i=$((i+1))
done

# 6. Start hermes in each worker pane
sleep 1
i=1
for p in $ALL_PANES; do
  tmux send-keys -t "$SESSION":1.$p 'hermes' Enter
  i=$((i+1))
done

# 7. Wait for prompt_toolkit, then send worker role prompt
sleep 6
i=1
for p in $ALL_PANES; do
  WORKER_PROMPT="You are worker-$i in blocks session $SESSION. \
Read $SHARED/tasks/worker-$i.md. \
Protocol (REQUIRED): \
  1. Within 30s of starting: touch $SHARED/done/worker-$i-start \
  2. Read tasks/worker-$i.md, do the work, append to results/worker-$i.md \
  3. When done: touch $SHARED/done/worker-$i-final \
(start touch is the liveness signal — the Manager polls it; final touch means 'I finished')"
  tmux send-keys -t "$SESSION":1.$p "$WORKER_PROMPT" Enter
  i=$((i+1))
done

# 8. Output the activation message (this is what the calling Hermes reads)
cat <<EOF
✓ Manager mode activated.
  Session:   $SESSION
  Workers:   $N panes in tmux session $SESSION
  Shared:    $SHARED
  Protocol:  \$SHARED/tasks/ for sub-tasks, \$SHARED/done/ for completion signals

Tell me your task. I will break it into $N sub-tasks, dispatch to workers,
poll for results, and report back here.
EOF
```

> **Implementation note:** the 2x3 and 2x4 cases above are stubs — the column-extension logic for N>4 is incomplete in this draft. For 2x3, after building 2x2, you need to split-h on the rightmost pane in EACH row to add a third column. For 2x4, repeat. The general pattern is: build a 2x2 first, then for each extra column, split-h on the rightmost pane of each row. Pane indices will shift each time, so the cleanest approach is to use `tmux list-panes` to find the rightmost pane dynamically, OR use `-t :1` (the active pane) after a `select-pane` to the rightmost pane.

## Recipe: 2x2 Default (the canonical pattern)

The order is: explicit session size → split empty shells → force equal sizes → only then start hermes. With `set -g base-index 1` and `setw -g pane-base-index 1` in `~/.tmux.conf` (recommended), the first window is 1 and first pane is 1 — pane indices are 1, 2, 3, 4.

```bash
SESSION="blocks-2x2-$(date +%H%M%S)"

# 1. Create session with explicit size (detached sessions have no size otherwise)
tmux new-session -d -s "$SESSION" -x 200 -y 50

# 2. Split into 4 EMPTY shells (no hermes yet)
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2

# 3. Read actual session size, compute target pane size = W/2 x H/2
read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
PANE_W=$((W/2))
PANE_H=$((H/2))

# 4. Force each pane to the exact equal size
#    NOTE: do NOT call `select-layout tiled` here. It's a no-op for a perfect 2x2
#    but if any pane is even 1 cell off, tiled will re-compute and may give you
#    uneven results. Stick with explicit resize-pane.
for i in 1 2 3 4; do
  tmux resize-pane -t "$SESSION":1.$i -x $PANE_W -y $PANE_H
done

# 5. Tag each pane for easy identification
for i in 1 2 3 4; do
  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
done

# 6. NOW start hermes in each pane (size is stable, prompt_toolkit will fit)
sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'hermes -p researcher' Enter
tmux send-keys -t "$SESSION":1.3 'hermes -p reviewer' Enter
tmux send-keys -t "$SESSION":1.4 'hermes -p ops' Enter

# 7. Wait for prompt_toolkit to render, then attach
sleep 6
echo "=== final pane sizes ==="
tmux list-panes -t "$SESSION" -F '  pane #{pane_index} title=#{pane_title} size=#{pane_width}x#{pane_height}'
tmux attach -t "$SESSION"
```

Expected output: all four panes 99x24 or 100x25 (1-cell off due to borders — that's tmux's natural minimum granularity).

## Recipe: 6 Panes (2x3 grid) — the next size up

Same pattern as 2x2, but with `split-window -h` and `split-window -v` called in a different order to build a 2-row × 3-col grid. Even number (6) → perfectly equalisable.

```bash
SESSION="blocks-6-$(date +%H%M%S)"

# 1. Explicit session size (must be wide enough for 3 columns)
tmux new-session -d -s "$SESSION" -x 240 -y 50

# 2. Build 6 empty shells:
#    row 1: pane 1, 2 (split-h)
#    row 2: pane 3, 4, 5, 6 (split-h twice + 2 verticals)
tmux split-window -h -t "$SESSION":1           # panes 1, 2
tmux split-window -v -t "$SESSION":1.1         # pane 3 below pane 1
tmux split-window -v -t "$SESSION":1.2         # pane 4 below pane 2
tmux split-window -h -t "$SESSION":1.3         # pane 5 right of pane 3
tmux split-window -h -t "$SESSION":1.4         # pane 6 right of pane 4

# 3. Force equal size: 2 rows × 3 cols = each pane 80x25 (240/3 x 50/2)
read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
PANE_W=$((W/3))
PANE_H=$((H/2))
for i in 1 2 3 4 5 6; do
  tmux resize-pane -t "$SESSION":1.$i -x $PANE_W -y $PANE_H
done

# 4. NO select-layout tiled — keep the explicit 80x25 sizing
#    (tiled is harmless for pure 2x3 grids, but we already have exact sizes)

# 5. Tag + start hermes
for i in 1 2 3 4 5 6; do
  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
done
sleep 1
for i in 1 2 3 4 5 6; do
  tmux send-keys -t "$SESSION":1.$i "hermes" Enter
done
sleep 6
tmux list-panes -t "$SESSION" -F '  pane #{pane_index} size=#{pane_width}x#{pane_height}'
tmux attach -t "$SESSION"
```

For 8 panes (2x4 or 4x2), the same pattern: `W/4 x H/2` or `W/2 x H/4` panes.

## Recipe: 2 Panes (Left/Right or Top/Bottom)

Even N=2, trivially equal — but still split-shell-first, then hermes:

**Left/right (2x1):**
```bash
SESSION="blocks-2-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1

# Force equal halves
read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
for i in 1 2; do
  tmux resize-pane -t "$SESSION":1.$i -x $((W/2)) -y $H
done

# Now start hermes
sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'hermes -p researcher' Enter
sleep 6 && tmux attach -t "$SESSION"
```

**Top/bottom (1x2):**
```bash
SESSION="blocks-2v-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -v -t "$SESSION":1

read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
for i in 1 2; do
  tmux resize-pane -t "$SESSION":1.$i -x $W -y $((H/2))
done

sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'hermes -p ops' Enter
sleep 6 && tmux attach -t "$SESSION"
```

**Variation: 1 hermes pane + 1 long-running shell** (e.g. code left, logs right). Same as `Left/right` above but swap the second pane's `hermes` for a long-running command:

```bash
SESSION="blocks-codelogs-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1
# (resize loop as above)
sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'tail -f ~/server.log' Enter
sleep 6 && tmux attach -t "$SESSION"
```

## Recipe: List / Attach / Kill

```bash
# List all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' || echo "no blocks sessions"

# Attach to a specific one
tmux attach -t blocks-2x2-143022

# Kill all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' | xargs -I {} tmux kill-session -t {}

# Kill just one
tmux kill-session -t blocks-2x2-143022

# Kill one pane inside a blocks session (e.g. coder is done)
tmux send-keys -t blocks-2x2-143022:1.1 '/exit' Enter
# Pane stays as a dead shell. To remove it:
tmux kill-pane -t blocks-2x2-143022:1.1
```

## Customisation: Profiles

Each pane can use a different `-p` profile for total isolation of skills, memory, sessions, and config. To create a profile:

```bash
hermes profile create coder --clone default
hermes profile create researcher --clone default
# Edit each profile's config independently
hermes -p coder config set model.default <model>
hermes -p researcher config set model.default <model>
```

If you skip profile creation, just call `hermes` without `-p` — all panes share the default profile, which is fine when you just want multiple windows into the same Hermes (e.g. one with `--continue` to a long session, others for fresh work).

## Customisation: Per-Pane Startup Prompt

You can pre-load a task into a pane so the agent starts working immediately. Use `send-keys` after the 6s warm-up, or pass it as the first message via `hermes -c <session> -q "..."` in non-interactive mode. For interactive panes, the cleanest trick is to send the prompt after the prompt_toolkit UI is up:

```bash
sleep 6
tmux send-keys -t "$SESSION":1.1 'Build a FastAPI user service with JWT auth' Enter
```

## Multi-Repo Code Editing (add -w)

If multiple panes will edit the same git repo, add `-w` so each pane works in its own git worktree — prevents index lock conflicts:

```bash
tmux send-keys -t "$SESSION":1.1 'hermes -p coder -w' Enter
tmux send-keys -t "$SESSION":1.2 'hermes -p reviewer -w' Enter
```

`-w` automatically creates a worktree per agent. When done, the user merges worktrees back manually or via `hermes` slash commands.

## One-Shot Helpers

The two Recipes above ([2x2 Default](#recipe-2x2-default-the-canonical-pattern) and [2 Panes](#recipe-2-panes-leftright-or-topbottom)) are the working templates — copy them, swap profile names or paths. The snippets below are quick utilities, not alternative Recipes.

**Reattach to a previous blocks session:**
```bash
SESSION=$(tmux list-sessions -F '#{session_name}' | grep '^blocks-' | tail -1)
tmux attach -t "$SESSION"
```

**Cleanup script (drop in ~/.local/bin/blocks-kill-all):**
```bash
#!/bin/bash
tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^blocks-' | while read s; do
  echo "killing $s"
  tmux kill-session -t "$s"
done
```

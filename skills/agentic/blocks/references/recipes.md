# Recipes

## Quick Spawn Reference (copy-paste-ready)

The 4 most common spawn patterns, self-contained. **An agent invoking blocks should pick one of these, copy it verbatim into a `terminal` tool call, and run.** The detailed Recipes below explain the why behind each step.

> `AGENT_CMD` **must be set explicitly** — blocks is agent-agnostic, there is **no default**. Run any recipe with `AGENT_CMD=hermes|claude|codex|aider bash <recipe>.sh`, or the recipe will error out before spawning. Other vars: `BLOCKS_TMUX_SESSION=my-name` overrides the auto-generated session name; `BLOCKS_WORKERS=N` (manager mode) overrides the default 4.

### A. 2x2 flat (4 panes, no coordination)

```bash
# Required: AGENT_CMD must be set (blocks is agent-agnostic; no default)
if [ -z "${AGENT_CMD:-}" ]; then
  echo "ERROR: AGENT_CMD is unset. Pick one before spawning:" >&2
  echo "  AGENT_CMD=hermes bash <recipe>.sh   # Hermes" >&2
  echo "  AGENT_CMD=claude bash <recipe>.sh   # Claude Code" >&2
  echo "  AGENT_CMD=codex  bash <recipe>.sh   # Codex" >&2
  echo "  AGENT_CMD=aider  bash <recipe>.sh   # Aider" >&2
  echo "See blocks/SKILL.md ## Quickstart for context." >&2
  exit 1
fi

SESSION="${BLOCKS_TMUX_SESSION:-blocks-2x2-$(date +%H%M%S)}"
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux split-window -h  -t "$SESSION":1
tmux split-window -v  -t "$SESSION":1.1
tmux split-window -v  -t "$SESSION":1.2
# Force equal sizing: tiled FIRST, then resize-pane (resize-pane alone is unreliable on macOS tmux 3.x)
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
for i in 1 2 3 4; do tmux resize-pane -t "$SESSION":1.$i -x 110 -y 25; done
for i in 1 2 3 4; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
for i in 1 2 3 4; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
sleep 6 && tmux attach -t "$SESSION"
```

### B. 2x1 flat (2 panes, side by side)

```bash
# Required: AGENT_CMD must be set (blocks is agent-agnostic; no default)
if [ -z "${AGENT_CMD:-}" ]; then
  echo "ERROR: AGENT_CMD is unset. Pick one before spawning:" >&2
  echo "  AGENT_CMD=hermes bash <recipe>.sh   # Hermes" >&2
  echo "  AGENT_CMD=claude bash <recipe>.sh   # Claude Code" >&2
  echo "  AGENT_CMD=codex  bash <recipe>.sh   # Codex" >&2
  echo "  AGENT_CMD=aider  bash <recipe>.sh   # Aider" >&2
  echo "See blocks/SKILL.md ## Quickstart for context." >&2
  exit 1
fi

SESSION="${BLOCKS_TMUX_SESSION:-blocks-2-$(date +%H%M%S)}"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1
for i in 1 2; do tmux resize-pane -t "$SESSION":1.$i -x 100 -y 50; done
for i in 1 2; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
for i in 1 2; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
sleep 6 && tmux attach -t "$SESSION"
```

### C. 2x3 flat (6 panes, 3 cols × 2 rows)

```bash
# Required: AGENT_CMD must be set (blocks is agent-agnostic; no default)
if [ -z "${AGENT_CMD:-}" ]; then
  echo "ERROR: AGENT_CMD is unset. Pick one before spawning:" >&2
  echo "  AGENT_CMD=hermes bash <recipe>.sh   # Hermes" >&2
  echo "  AGENT_CMD=claude bash <recipe>.sh   # Claude Code" >&2
  echo "  AGENT_CMD=codex  bash <recipe>.sh   # Codex" >&2
  echo "  AGENT_CMD=aider  bash <recipe>.sh   # Aider" >&2
  echo "See blocks/SKILL.md ## Quickstart for context." >&2
  exit 1
fi

SESSION="${BLOCKS_TMUX_SESSION:-blocks-6-$(date +%H%M%S)}"
tmux new-session -d -s "$SESSION" -x 300 -y 50
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2
tmux split-window -h -t "$SESSION":1.2
tmux split-window -h -t "$SESSION":1.4
# Force equal sizing: tiled FIRST, then resize-pane
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
for i in 1 2 3 4 5 6; do tmux resize-pane -t "$SESSION":1.$i -x 100 -y 25; done
for i in 1 2 3 4 5 6; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
for i in 1 2 3 4 5 6; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
sleep 6 && tmux attach -t "$SESSION"
```

### D. Manager mode (current chat = Manager; spawns N workers)

```bash
N=${BLOCKS_WORKERS:-4}
# Required: AGENT_CMD must be set (blocks is agent-agnostic; no default)
if [ -z "${AGENT_CMD:-}" ]; then
  echo "ERROR: AGENT_CMD is unset. Pick one before spawning:" >&2
  echo "  AGENT_CMD=hermes bash <recipe>.sh   # Hermes" >&2
  echo "  AGENT_CMD=claude bash <recipe>.sh   # Claude Code" >&2
  echo "  AGENT_CMD=codex  bash <recipe>.sh   # Codex" >&2
  echo "  AGENT_CMD=aider  bash <recipe>.sh   # Aider" >&2
  echo "See blocks/SKILL.md ## Quickstart for context." >&2
  exit 1
fi
SESSION="${BLOCKS_TMUX_SESSION:-blocks-mgr-$(date +%H%M%S)}"
SHARED="$HOME/blocks-shared/$SESSION"
mkdir -p "$SHARED"/{tasks,results,done}

# Timestamp marker for recovery-scan.sh
touch /tmp/blocks-mgr-session

W=220; H=50
if [ "$N" -ge 6 ]; then W=300; fi
if [ "$N" -ge 8 ]; then W=380; fi
tmux new-session -d -s "$SESSION" -x $W -y $H

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

# Force equal sizing: tiled FIRST, then resize-pane (NOT select-layout tiled on 1+N Manager+Workers)
# This is a pure worker grid, so tiled is safe here.
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
COLS=$((N/2))
PANE_W=$((W / COLS))
PANE_H=$((H / 2))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

i=1
for p in $ALL_PANES; do
  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
  i=$((i+1))
done
sleep 1
i=1
for p in $ALL_PANES; do
  tmux send-keys -t "$SESSION":1.$p "$AGENT_CMD" Enter
  i=$((i+1))
done
sleep 6
i=1
for p in $ALL_PANES; do
  PROMPT="You are worker-$i in blocks session $SESSION. Read $SHARED/tasks/worker-$i.md. Within 30s: touch $SHARED/done/worker-$i-start. After work: write $SHARED/results/worker-$i.md, then touch $SHARED/done/worker-$i-final."
  tmux send-keys -t "$SESSION":1.$p "$PROMPT" Enter
  i=$((i+1))
done
echo "✓ Manager mode activated. Session: $SESSION. Shared: $SHARED. Tell me your task."
```

### E. List / attach / kill

```bash
# List all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' || echo "no blocks sessions"
# Attach to a specific session
tmux attach -t <session-name>
# Kill all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' | xargs -I {} tmux kill-session -t {}
```

---

## Detailed Recipes

Working templates — copy, swap profile names or paths. Base-index 1 assumed (see ../templates/tmux.conf.blocks).

### Recipe: Spawn N Workers in tmux (the only recipe blocks --manager needs)

This is the working template. It only spawns the workers — the Manager is the calling agent session, not a tmux pane.

```bash
# N is the number of workers (must be even: 2/4/6/8). Default 4.
N=${BLOCKS_WORKERS:-4}
SESSION="blocks-mgr-$(date +%H%M%S)"
SHARED="$HOME/blocks-shared/$SESSION"

# 1. Create shared directory structure
mkdir -p "$SHARED"/{tasks,results,done}

# Timestamp marker for recovery-scan.sh
touch /tmp/blocks-mgr-session

# 2. Session size: wider for more workers (each worker needs at least 50 cells wide)
W=200
H=50
if [ "$N" -ge 4 ]; then W=220; fi
if [ "$N" -ge 6 ]; then W=300; fi
if [ "$N" -ge 8 ]; then W=380; fi
tmux new-session -d -s "$SESSION" -x $W -y $H

COLS=$((N/2))

# 3. Build N-worker grid: 2 rows × (N/2) cols.
#
#    IMPORTANT (macOS tmux 3.x): `resize-pane` alone after splits produces
#    uneven grids (e.g. 109x22, 109x1, 109x25, 110x50). You MUST call
#    `select-layout tiled` after the splits, BEFORE the resize-pane loop,
#    to force tmux to recompute equal sizes. Then resize-pane for fine
#    tuning. See references/tmux-grid-bug.md for the transcript.
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

# 3b. Force equal sizing: tiled THEN resize-pane (not resize-pane alone).
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
PANE_W=$((W / COLS))
PANE_H=$((H / 2))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

# 4. Tag panes as worker-1..worker-N (left-to-right, top-to-bottom)
i=1
for p in $ALL_PANES; do
  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
  i=$((i+1))
done

# 5. Start $AGENT_CMD in each worker pane
sleep 1
i=1
for p in $ALL_PANES; do
  tmux send-keys -t "$SESSION":1.$p "$AGENT_CMD" Enter
  i=$((i+1))
done

# 6. Wait for prompt_toolkit, then send worker role prompt
# hermes default ~6s. For other agents adjust: codex ~0.5s, claude ~3s, aider ~1s.
# See references/agent-compatibility.md § TUI warm-up.
sleep 6
i=1
for p in $ALL_PANES; do
  WORKER_PROMPT="You are worker-$i in blocks session $SESSION. \
Read $SHARED/tasks/worker-$i.md. \
Protocol (REQUIRED — protects against tmux server crash): \
  1. WITHIN 30 SECONDS of starting: touch $SHARED/done/worker-$i-start \
  2. Read tasks/worker-$i.md, do the work, append to results/worker-$i.md \
  3. When done: touch $SHARED/done/worker-$i-final. \
If your task involves web search or page fetching, use the agent-reach skill (Exa/Jina/yt-dlp), NOT raw curl — SSRN/ResearchGate/Nature/ScienceDirect block direct curl. Cap any single fetch at 60s; if it fails, mark '无法核对 — anti-bot' and move on. \
(start touch is the liveness signal — the Manager polls it; final touch means 'I finished')"
  tmux send-keys -t "$SESSION":1.$p "$WORKER_PROMPT" Enter
  i=$((i+1))
done

# 7. Output the activation message (this is what the calling agent reads)
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

## Recipe: 2x2 Default (the canonical pattern)

The order is: explicit session size → split empty shells → `select-layout tiled` → resize-pane to exact size → start `$AGENT_CMD`. With `set -g base-index 1` and `setw -g pane-base-index 1` in `~/.tmux.conf` (recommended), pane indices are 1, 2, 3, 4.

```bash
SESSION="blocks-2x2-$(date +%H%M%S)"

# 1. Create session with explicit size (detached sessions have no size otherwise)
tmux new-session -d -s "$SESSION" -x 220 -y 50

# 2. Split into 4 EMPTY shells (no $AGENT_CMD yet)
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2

# 3. Force equal sizing: select-layout tiled FIRST, then resize-pane.
#    On macOS tmux 3.x, resize-pane alone is unreliable (one pane collapses to 1 row).
#    tiled re-computes geometry; resize-pane then fine-tunes to exact dimensions.
#    See references/tmux-grid-bug.md for the full transcript.
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
for i in 1 2 3 4; do
  tmux resize-pane -t "$SESSION":1.$i -x 110 -y 25
done

# Sanity check: if any pane is < 5 rows tall, repeat the tiled chain fallback.
MIN_H=$(tmux list-panes -t "$SESSION" -F '#{pane_height}' | sort -n | head -1)
if [ "$MIN_H" -lt 5 ]; then
  tmux select-layout -t "$SESSION" even-vertical
  tmux select-layout -t "$SESSION" even-horizontal
  tmux select-layout -t "$SESSION" tiled
fi

# 4. Tag each pane for easy identification
for i in 1 2 3 4; do
  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
done

# 5. NOW start $AGENT_CMD in each pane (size is stable, prompt_toolkit will fit)
sleep 1
tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p researcher" Enter
tmux send-keys -t "$SESSION":1.3 "$AGENT_CMD -p reviewer" Enter
tmux send-keys -t "$SESSION":1.4 "$AGENT_CMD -p ops" Enter

# 6. Wait for prompt_toolkit to render, then attach
sleep 6
echo "=== final pane sizes ==="
tmux list-panes -t "$SESSION" -F '  pane #{pane_index} title=#{pane_title} size=#{pane_width}x#{pane_height}'
tmux attach -t "$SESSION"
```

Expected output: all four panes within 1 cell of 110x25 (1-cell off due to borders — tmux's natural minimum granularity).

## Recipe: 6 Panes (2x3 grid) — the next size up

Same pattern as 2x2, but with `split-window -h` and `split-window -v` called in a different order to build a 2-row × 3-col grid. Even number (6) → perfectly equalisable.

```bash
SESSION="blocks-6-$(date +%H%M%S)"

# 1. Explicit session size (must be wide enough for 3 columns)
tmux new-session -d -s "$SESSION" -x 300 -y 50

# 2. Build 6 empty shells
tmux split-window -h -t "$SESSION":1           # panes 1, 2
tmux split-window -v -t "$SESSION":1.1         # pane 3 below pane 1
tmux split-window -v -t "$SESSION":1.2         # pane 4 below pane 2
tmux split-window -h -t "$SESSION":1.3         # pane 5 right of pane 3
tmux split-window -h -t "$SESSION":1.4         # pane 6 right of pane 4

# 3. Force equal size: tiled FIRST, then resize-pane
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1
for i in 1 2 3 4 5 6; do
  tmux resize-pane -t "$SESSION":1.$i -x 100 -y 25
done

# 4. Tag + start $AGENT_CMD
for i in 1 2 3 4 5 6; do
  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
done
sleep 1
for i in 1 2 3 4 5 6; do
  tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter
done
sleep 6
tmux list-panes -t "$SESSION" -F '  pane #{pane_index} size=#{pane_width}x#{pane_height}'
tmux attach -t "$SESSION"
```

For 8 panes (2x4), the same pattern: `W=380`, target pane size `W/4 x H/2`.

## Recipe: 2 Panes (Left/Right or Top/Bottom)

Even N=2, trivially equal — but still split-shell-first, then $AGENT_CMD:

**Left/right (2x1):**
```bash
SESSION="blocks-2-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1

# Force equal halves
for i in 1 2; do
  tmux resize-pane -t "$SESSION":1.$i -x 100 -y 50
done

# Now start $AGENT_CMD
sleep 1
tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p researcher" Enter
sleep 6 && tmux attach -t "$SESSION"
```

**Top/bottom (1x2):**
```bash
SESSION="blocks-2v-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -v -t "$SESSION":1

for i in 1 2; do
  tmux resize-pane -t "$SESSION":1.$i -x 200 -y 25
done

sleep 1
tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p ops" Enter
sleep 6 && tmux attach -t "$SESSION"
```

**Variation: 1 agent pane + 1 long-running shell** (e.g. code left, logs right):

```bash
SESSION="blocks-codelogs-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1
for i in 1 2; do tmux resize-pane -t "$SESSION":1.$i -x 100 -y 50; done
sleep 1
tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
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

Each pane can use a different profile for total isolation of skills, memory, sessions, and config. The exact mechanism depends on your agent CLI:

```bash
# hermes (default): create a profile, then launch with -p
hermes profile create coder --clone default
hermes profile create researcher --clone default
hermes -p coder config set model.default <model>
hermes -p researcher config set model.default <model>

# Other agents: consult their docs for the equivalent. Common patterns:
#   claude code  →  CLAUDE_CONFIG_DIR=~/.claude-pane-N claude
#   codex        →  --profile NAME (separate <NAME>.config.toml)
#   aider        →  --config ~/.aider-pane-N.yml
```

If you skip profile creation, just call `$AGENT_CMD` without `-p` — all panes share the default profile, which is fine when you just want multiple windows into the same agent. Note: `-p` and profile creation are hermes-specific; consult your agent CLI's docs for the equivalent.

## Customisation: Per-Pane Startup Prompt

Pre-load a task into a pane so the agent starts working immediately. Send the prompt after the prompt_toolkit UI is up:

```bash
sleep 6
tmux send-keys -t "$SESSION":1.1 'Build a FastAPI user service with JWT auth' Enter
```

## Multi-Repo Code Editing (add -w)

If multiple panes will edit the same git repo, each pane should work in its own git worktree to prevent index lock conflicts. Add the worktree manually before starting the agent:

```bash
# hermes: -w flag (auto-creates worktree)
tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder -w" Enter
# claude code: -w / --worktree flag
tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD --worktree pane2" Enter
# codex / aider: no -w flag; do git worktree add manually in each pane
```

`-w` is hermes/claude-code only. For codex and aider, do `git worktree add <path> -b <branch>` in each pane before starting the agent. See `references/agent-compatibility.md` § Worktree.

## One-Shot Helpers

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

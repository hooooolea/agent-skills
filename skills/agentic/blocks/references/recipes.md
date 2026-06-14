# Recipes

## Quick Spawn Reference (copy-paste-ready)

**One recipe for any N.** An agent invoking blocks should pick the mode, set N, copy the recipe verbatim into a `terminal` tool call, and run.

> `AGENT_CMD` **must be set explicitly** — blocks is agent-agnostic, there is **no default**. Run with `AGENT_CMD=hermes|claude|codex|aider bash <recipe>.sh`, or the recipe will error out before spawning. Other vars: `BLOCKS_TMUX_SESSION=my-name` overrides the auto-generated session name; `N` defaults to 4.

### A. Flat mode — N isolated panes (any N ≥ 1)

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

N=${1:-4}  # any N ≥ 1 — 3, 5, 7, 9 all work
# NOTE: AGENT_CMD guard above is duplicated in Recipe B. Keep both in sync.

# --- Calculate window size from N ---
# Target: each pane ≥ 80×20. tiled arranges N panes as ≈ceil(sqrt(N)) cols.
COLS=$(awk "BEGIN {print int(sqrt($N)+0.999)}")
ROWS=$(( (N + COLS - 1) / COLS ))
W=$(( COLS * 100 + 20 ))
H=$(( ROWS * 25 + 5 ))
[ $W -lt 200 ] && W=200
[ $H -lt 45 ] && H=45

SESSION="${BLOCKS_TMUX_SESSION:-blocks-${N}-$(date +%H%M%S)}"

# 1. Create session with explicit size
tmux new-session -d -s "$SESSION" -x $W -y $H

# 2. Build a horizontal chain of N panes
#    (split-window -h N-1 times → select-layout tiled rearranges into optimal grid)
for i in $(seq 2 $N); do
  tmux split-window -h -t "$SESSION":1
done

# 3. Force equal sizing: tiled FIRST, then resize-pane
#    On macOS tmux 3.x, resize-pane alone is unreliable (one pane collapses to 1 row).
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1

# --- Fallback for stubborn tmux versions ---
MIN_H=$(tmux list-panes -t "$SESSION" -F '#{pane_height}' | sort -n | head -1)
if [ "$MIN_H" -lt 5 ]; then
  tmux select-layout -t "$SESSION" even-vertical
  tmux select-layout -t "$SESSION" even-horizontal
  tmux select-layout -t "$SESSION" tiled
fi

# 4. Resize every pane to equal dimensions
PANE_W=$(( (W - 4) / COLS ))
PANE_H=$(( (H - 2) / ROWS ))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}' | sort -n)
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

# 5. Tag panes (left-to-right, top-to-bottom after tiled)
i=1
for p in $ALL_PANES; do
  tmux select-pane -t "$SESSION":1.$p -T "pane-$i"
  i=$((i+1))
done

# 6. Start $AGENT_CMD in each pane
sleep 1
for p in $ALL_PANES; do
  tmux send-keys -t "$SESSION":1.$p "$AGENT_CMD" Enter
done

sleep 6
echo "=== final pane sizes ==="
tmux list-panes -t "$SESSION" -F '  pane #{pane_index} title=#{pane_title} size=#{pane_width}x#{pane_height}'
tmux attach -t "$SESSION"
```

### B. Manager mode — current chat = Manager, N workers in tmux (any N ≥ 1)

```bash
N=${BLOCKS_WORKERS:-4}  # any N ≥ 1
# NOTE: AGENT_CMD guard below is duplicated from Recipe A. Keep both in sync.
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

# --- Calculate window size from N ---
COLS=$(awk "BEGIN {print int(sqrt($N)+0.999)}")
ROWS=$(( (N + COLS - 1) / COLS ))
W=$(( COLS * 100 + 20 ))
H=$(( ROWS * 25 + 5 ))
[ $W -lt 200 ] && W=200
[ $H -lt 45 ] && H=45

# 1. Create session with explicit size
tmux new-session -d -s "$SESSION" -x $W -y $H

# 2. Build N panes as horizontal chain → tiled rearranges into optimal grid
for i in $(seq 2 $N); do
  tmux split-window -h -t "$SESSION":1
done

# 3. Force equal sizing (tiled is safe on pure worker grids — no Manager pane)
sleep 1
tmux select-layout -t "$SESSION" tiled
sleep 1

MIN_H=$(tmux list-panes -t "$SESSION" -F '#{pane_height}' | sort -n | head -1)
if [ "$MIN_H" -lt 5 ]; then
  tmux select-layout -t "$SESSION" even-vertical
  tmux select-layout -t "$SESSION" even-horizontal
  tmux select-layout -t "$SESSION" tiled
fi

PANE_W=$(( (W - 4) / COLS ))
PANE_H=$(( (H - 2) / ROWS ))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}' | sort -n)
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

# 4. Tag panes as worker-1..worker-N
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

### C. List / attach / kill

```bash
# List all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' || echo "no blocks sessions"
# Attach to a specific session
tmux attach -t <session-name>
# Kill all blocks sessions
tmux list-sessions -F '#{session_name}' | grep '^blocks-' | xargs -I {} tmux kill-session -t {}
# Kill just one
tmux kill-session -t blocks-2x2-143022
# Kill one pane inside a blocks session
tmux send-keys -t blocks-2x2-143022:1.1 '/exit' Enter
tmux kill-pane -t blocks-2x2-143022:1.1
```

---

## How the Grid Algorithm Works

The recipe above works for **any N ≥ 1** (odd or even). No more "N must be even" restriction.

**Algorithm:**
1. Calculate window size from N: `cols = ceil(sqrt(N))`, `rows = ceil(N/cols)`, each pane gets ≥ 80×20
2. Create N panes as a horizontal chain (`split-window -h` N−1 times)
3. `select-layout tiled` — tmux rearranges the chain into the optimal ≈square grid
4. `resize-pane` every pane to equal `(W/cols) × (H/rows)` dimensions
5. Start `$AGENT_CMD` in each pane, wait 6s for prompt_toolkit, attach

**Expected layouts (empirically observed on macOS tmux 3.x):**

| N | tiled result | Layout |
|---|-------------|--------|
| 1 | 1×1 | Full window |
| 2 | 1×2 | Side by side |
| 3 | 2 rows (2+1) | Top row 2, bottom 1 |
| 4 | 2×2 | Classic four-square |
| 5 | 2 rows (3+2) | Top 3, bottom 2 |
| 6 | 2×3 | 3 cols × 2 rows |
| 7 | 2 rows (4+3) | Top 4, bottom 3 |
| 8 | 2×4 | 4 cols × 2 rows |
| 9 | 3×3 | Perfect square |
| 10 | 2 rows (5+5) | Two even rows |
| 11 | 3 rows (4+4+3) | 3 rows, bottom incomplete |
| 12 | 3×4 or 4×3 | Depends on window aspect ratio |

**Why horizontal chain + tiled instead of hand-coded splits:**
- Hand-coded splits must be rewritten for every N (and every grid dimension change)
- Chain + tiled is one algorithm for all N — no special cases
- tiled has been in tmux since 2.x and produces equal-sized panes by construction
- The tiled → resize-pane chain (with even-vertical/even-horizontal fallback) handles the macOS tmux 3.x sizing bug (Pitfall 20)

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

`-w` is hermes/claude-code only. For codex and aider, do `git worktree add <path> -b <branch>` in each pane before starting the agent. See `agent-compatibility.md` § Worktree.

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

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
tmux select-layout -t "$SESSION" tiled
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
tmux select-layout -t "$SESSION" tiled
for i in 1 2 3 4 5 6; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
for i in 1 2 3 4 5 6; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
sleep 6 && tmux attach -t "$SESSION"
```

### D. Manager mode (current chat = Manager; spawns 4 workers)

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

tmux new-session -d -s "$SESSION" -x 220 -y 50
if [ "$N" -eq 4 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
elif [ "$N" -eq 6 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.4
fi
tmux select-layout -t "$SESSION" tiled
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
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

     1|# Recipes
     2|
     3|## Quick Spawn Reference (copy-paste-ready)
     4|
     5|The 4 most common spawn patterns, self-contained. **An agent invoking blocks should pick one of these, copy it verbatim into a `terminal` tool call, and run.** The detailed Recipes below explain the why behind each step.
     6|
     7|> `AGENT_CMD` **must be set explicitly** — blocks is agent-agnostic, there is **no default**. Run any recipe with `AGENT_CMD=hermes|claude|codex|aider bash <recipe>.sh`, or the recipe will error out before spawning. Other vars: `BLOCKS_TMUX_SESSION=my-name` overrides the auto-generated session name; `BLOCKS_WORKERS=N` (manager mode) overrides the default 4.
     8|
     9|### A. 2x2 flat (4 panes, no coordination)
    10|
    11|```bash
    12|SESSION="${BLOCKS_TMUX_SESSION:-blocks-2x2-$(date +%H%M%S)}"
    13|tmux new-session -d -s "$SESSION" -x 220 -y 50
    14|tmux split-window -h  -t "$SESSION":1
    15|tmux split-window -v  -t "$SESSION":1.1
    16|tmux split-window -v  -t "$SESSION":1.2
    17|tmux select-layout -t "$SESSION" tiled
    18|for i in 1 2 3 4; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
    19|for i in 1 2 3 4; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
    20|sleep 6 && tmux attach -t "$SESSION"
    21|```
    22|
    23|### B. 2x1 flat (2 panes, side by side)
    24|
    25|```bash
    26|SESSION="${BLOCKS_TMUX_SESSION:-blocks-2-$(date +%H%M%S)}"
    27|tmux new-session -d -s "$SESSION" -x 200 -y 50
    28|tmux split-window -h -t "$SESSION":1
    29|for i in 1 2; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
    30|for i in 1 2; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
    31|sleep 6 && tmux attach -t "$SESSION"
    32|```
    33|
    34|### C. 2x3 flat (6 panes, 3 cols × 2 rows)
    35|
    36|```bash
    37|SESSION="${BLOCKS_TMUX_SESSION:-blocks-6-$(date +%H%M%S)}"
    38|tmux new-session -d -s "$SESSION" -x 300 -y 50
    39|tmux split-window -h -t "$SESSION":1
    40|tmux split-window -v -t "$SESSION":1.1
    41|tmux split-window -v -t "$SESSION":1.2
    42|tmux split-window -h -t "$SESSION":1.2
    43|tmux split-window -h -t "$SESSION":1.4
    44|tmux select-layout -t "$SESSION" tiled
    45|for i in 1 2 3 4 5 6; do tmux select-pane -t "$SESSION":1.$i -T "pane-$i"; done
    46|for i in 1 2 3 4 5 6; do tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter; done
    47|sleep 6 && tmux attach -t "$SESSION"
    48|```
    49|
    50|### D. Manager mode (current chat = Manager; spawns 4 workers)
    51|
    52|```bash
    53|N=${BLOCKS_WORKERS:-4}
    54|SESSION="${BLOCKS_TMUX_SESSION:-blocks-mgr-$(date +%H%M%S)}"
    55|SHARED="$HOME/blocks-shared/$SESSION"
    56|mkdir -p "$SHARED"/{tasks,results,done}
    57|
    58|tmux new-session -d -s "$SESSION" -x 220 -y 50
    59|if [ "$N" -eq 4 ]; then
    60|  tmux split-window -h -t "$SESSION":1
    61|  tmux split-window -v -t "$SESSION":1.1
    62|  tmux split-window -v -t "$SESSION":1.2
    63|elif [ "$N" -eq 6 ]; then
    64|  tmux split-window -h -t "$SESSION":1
    65|  tmux split-window -v -t "$SESSION":1.1
    66|  tmux split-window -v -t "$SESSION":1.2
    67|  tmux split-window -h -t "$SESSION":1.2
    68|  tmux split-window -h -t "$SESSION":1.4
    69|fi
    70|tmux select-layout -t "$SESSION" tiled
    71|ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
    72|i=1
    73|for p in $ALL_PANES; do
    74|  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
    75|  i=$((i+1))
    76|done
    77|sleep 1
    78|i=1
    79|for p in $ALL_PANES; do
    80|  tmux send-keys -t "$SESSION":1.$p "$AGENT_CMD" Enter
    81|  i=$((i+1))
    82|done
    83|sleep 6
    84|i=1
    85|for p in $ALL_PANES; do
    86|  PROMPT="You are worker-$i in blocks session $SESSION. Read $SHARED/tasks/worker-$i.md. Within 30s: touch $SHARED/done/worker-$i-start. After work: write $SHARED/results/worker-$i.md, then touch $SHARED/done/worker-$i-final."
    87|  tmux send-keys -t "$SESSION":1.$p "$PROMPT" Enter
    88|  i=$((i+1))
    89|done
    90|echo "✓ Manager mode activated. Session: $SESSION. Shared: $SHARED. Tell me your task."
    91|```
    92|
    93|### E. List / attach / kill
    94|
    95|```bash
    96|# List all blocks sessions
    97|tmux list-sessions -F '#{session_name}' | grep '^blocks-' || echo "no blocks sessions"
    98|# Attach to a specific session
    99|tmux attach -t <session-name>
   100|# Kill all blocks sessions
   101|tmux list-sessions -F '#{session_name}' | grep '^blocks-' | xargs -I {} tmux kill-session -t {}
   102|```
   103|
   104|---
   105|
   106|## Detailed Recipes
   107|
   108|     1|     1|Working templates — copy, swap profile names or paths. Base-index 1 assumed (see ../templates/tmux.conf.blocks).
   109|     2|     2|
   110|     3|     3|### Recipe: Spawn N Workers in tmux (the only recipe blocks --manager needs)
   111|     4|     4|
   112|     5|     5|This is the working template. It only spawns the workers — the Manager is the calling agent session, not a tmux pane.
   113|     6|     6|
   114|     7|     7|```bash
   115|     8|     8|# N is the number of workers (must be even: 2/4/6/8). Default 4.
   116|     9|     9|N=${BLOCKS_WORKERS:-4}
   117|    10|    10|SESSION="blocks-mgr-$(date +%H%M%S)"
   118|    11|    11|SHARED="$HOME/blocks-shared/$SESSION"
   119|    12|    12|
   120|    13|    13|# 1. Create shared directory structure
   121|    14|    14|mkdir -p "$SHARED"/{tasks,results,done}
   122|    15|    15|
   123|    16|    16|# 2. Session size: wider for more workers (each worker needs at least 50 cells wide)
   124|    17|    17|W=200
   125|    18|    18|H=50
   126|    19|    19|if [ "$N" -ge 4 ]; then W=220; fi
   127|    20|    20|if [ "$N" -ge 6 ]; then W=300; fi
   128|    21|    21|if [ "$N" -ge 8 ]; then W=380; fi
   129|    22|    22|tmux new-session -d -s "$SESSION" -x $W -y $H
   130|    23|    23|
   131|    24|    24|COLS=$((N/2))
   132|    25|    25|
   133|    26|    26|# 3. Build N-worker grid: 2 rows × (N/2) cols.
   134|    27|    27|#
   135|    28|    28|#    IMPORTANT (macOS tmux 3.x): `resize-pane` alone after splits produces
   136|    29|    29|#    uneven grids (e.g. 109x22, 109x1, 109x25, 110x50). You MUST call
   137|    30|    30|#    `select-layout tiled` after the splits, BEFORE the resize-pane loop,
   138|    31|    31|#    to force tmux to recompute equal sizes. Then resize-pane for fine
   139|    32|    32|#    tuning. See references/tmux-grid-bug.md for the transcript.
   140|    33|    33|#
   141|    34|    34|#    Per-case split sequence (empirically verified, base-index 1):
   142|    35|    35|#      N=2: split-v on 1.1  → 1.1 (top), 1.2 (bottom)
   143|    36|    36|#      N=4: split-h on 1.1, then split-v on each of 1.1 and 1.2
   144|    37|    37|#           → 1.1 TL, 1.2 TR, 1.3 BL, 1.4 BR
   145|    38|    38|#      N=6: as 4, then split-h on 1.2 and split-h on 1.4
   146|    39|    39|#           → adds 1.5 (right of 1.2) and 1.6 (right of 1.4)
   147|    40|    40|#      N=8: as 6, then split-h on 1.5 and split-h on 1.6
   148|    41|    41|#           → adds 1.7 and 1.8
   149|    42|    42|if [ "$N" -eq 2 ]; then
   150|    43|    43|  tmux split-window -v -t "$SESSION":1
   151|    44|    44|elif [ "$N" -eq 4 ]; then
   152|    45|    45|  tmux split-window -h -t "$SESSION":1
   153|    46|    46|  tmux split-window -v -t "$SESSION":1.1
   154|    47|    47|  tmux split-window -v -t "$SESSION":1.2
   155|    48|    48|elif [ "$N" -eq 6 ]; then
   156|    49|    49|  tmux split-window -h -t "$SESSION":1
   157|    50|    50|  tmux split-window -v -t "$SESSION":1.1
   158|    51|    51|  tmux split-window -v -t "$SESSION":1.2
   159|    52|    52|  tmux split-window -h -t "$SESSION":1.2
   160|    53|    53|  tmux split-window -h -t "$SESSION":1.4
   161|    54|    54|elif [ "$N" -eq 8 ]; then
   162|    55|    55|  tmux split-window -h -t "$SESSION":1
   163|    56|    56|  tmux split-window -v -t "$SESSION":1.1
   164|    57|    57|  tmux split-window -v -t "$SESSION":1.2
   165|    58|    58|  tmux split-window -h -t "$SESSION":1.2
   166|    59|    59|  tmux split-window -h -t "$SESSION":1.4
   167|    60|    60|  tmux split-window -h -t "$SESSION":1.5
   168|    61|    61|  tmux split-window -h -t "$SESSION":1.6
   169|    62|    62|fi
   170|    63|    63|
   171|    64|    64|# 3b. Force equal sizing: tiled THEN resize-pane (not resize-pane alone).
   172|    65|    65|sleep 1
   173|    66|    66|tmux select-layout -t "$SESSION" tiled
   174|    67|    67|sleep 1
   175|    68|    68|PANE_W=$((W / COLS))
   176|    69|    69|PANE_H=$((H / 2))
   177|    70|    70|ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
   178|    71|    71|for p in $ALL_PANES; do
   179|    72|    72|  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
   180|    73|    73|done
   181|    74|    74|
   182|    75|    75|# 4. Tag panes as worker-1..worker-N (left-to-right, top-to-bottom)
   183|    76|    76|i=1
   184|    77|    77|for p in $ALL_PANES; do
   185|    78|    78|  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
   186|    79|    79|  i=$((i+1))
   187|    80|    80|done
   188|    81|    81|
   189|    82|    82|# 5. Start $AGENT_CMD in each worker pane
   190|    83|    83|sleep 1
   191|    84|    84|i=1
   192|    85|    85|for p in $ALL_PANES; do
   193|    86|    86|  tmux send-keys -t "$SESSION":1.$p "$AGENT_CMD" Enter
   194|    87|    87|  i=$((i+1))
   195|    88|    88|done
   196|    89|    89|
   197|    # 6. Wait for prompt_toolkit, then send worker role prompt
   198|    sleep 6   # hermes default. For other agents, adjust to their render time (codex ~0.5s, claude ~3s). See references/agent-compatibility.md.
   199|    92|    92|i=1
   200|    93|    93|for p in $ALL_PANES; do
   201|    94|    94|  WORKER_PROMPT="You are worker-$i in blocks session $SESSION. \
   202|    95|    95|Read $SHARED/tasks/worker-$i.md. \
   203|    96|    96|Protocol (REQUIRED — protects against tmux server crash): \
   204|    97|    97|  1. WITHIN 30 SECONDS of starting: touch $SHARED/done/worker-$i-start \
   205|    98|    98|  2. Read tasks/worker-$i.md, do the work, append to results/worker-$i.md \
   206|    99|    99|  3. When done: touch $SHARED/done/worker-$i-final. \
   207|   100|   100|If your task involves web search or page fetching, use the agent-reach skill (Exa/Jina/yt-dlp), NOT raw curl — SSRN/ResearchGate/Nature/ScienceDirect block direct curl. Cap any single fetch at 60s; if it fails, mark '无法核对 — anti-bot' and move on. \
   208|   101|   101|(start touch is the liveness signal — the Manager polls it; final touch means 'I finished')"
   209|   102|   102|  tmux send-keys -t "$SESSION":1.$p "$WORKER_PROMPT" Enter
   210|   103|   103|  i=$((i+1))
   211|   104|   104|done
   212|   105|   105|
   213|   106|   106|# 7. Output the activation message (this is what the calling agent reads)
   214|   107|   107|cat <<EOF
   215|   108|   108|✓ Manager mode activated.
   216|   109|   109|  Session:   $SESSION
   217|   110|   110|  Workers:   $N panes in tmux session $SESSION
   218|   111|   111|  Shared:    $SHARED
   219|   112|   112|  Protocol:  \$SHARED/tasks/ for sub-tasks, \$SHARED/done/ for completion signals
   220|   113|   113|
   221|   114|   114|Tell me your task. I will break it into $N sub-tasks, dispatch to workers,
   222|   115|   115|poll for results, and report back here.
   223|   116|   116|EOF
   224|   117|   117|```
   225|   118|   118|
   226|   119|   119|> **Implementation note:** the 2x3 and 2x4 cases above are stubs — the column-extension logic for N>4 is incomplete in this draft. For 2x3, after building 2x2, you need to split-h on the rightmost pane in EACH row to add a third column. For 2x4, repeat. The general pattern is: build a 2x2 first, then for each extra column, split-h on the rightmost pane of each row. Pane indices will shift each time, so the cleanest approach is to use `tmux list-panes` to find the rightmost pane dynamically, OR use `-t :1` (the active pane) after a `select-pane` to the rightmost pane.
   227|   120|   120|
   228|   121|   121|## Recipe: 2x2 Default (the canonical pattern)
   229|   122|   122|
   230|   123|   123|The order is: explicit session size → split empty shells → force equal sizes → only then start $AGENT_CMD. With `set -g base-index 1` and `setw -g pane-base-index 1` in `~/.tmux.conf` (recommended), the first window is 1 and first pane is 1 — pane indices are 1, 2, 3, 4.
   231|   124|   124|
   232|   125|   125|```bash
   233|   126|   126|SESSION="blocks-2x2-$(date +%H%M%S)"
   234|   127|   127|
   235|   128|   128|# 1. Create session with explicit size (detached sessions have no size otherwise)
   236|   129|   129|tmux new-session -d -s "$SESSION" -x 200 -y 50
   237|   130|   130|
   238|   131|   131|# 2. Split into 4 EMPTY shells (no $AGENT_CMD yet)
   239|   132|   132|tmux split-window -h -t "$SESSION":1
   240|   133|   133|tmux split-window -v -t "$SESSION":1.1
   241|   134|   134|tmux split-window -v -t "$SESSION":1.2
   242|   135|   135|
   243|   136|   136|# 3. Read actual session size, compute target pane size = W/2 x H/2
   244|   137|   137|read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
   245|   138|   138|PANE_W=$((W/2))
   246|   139|   139|PANE_H=$((H/2))
   247|   140|   140|
   248|   141|   # 4. Force each pane to the exact equal size
   249|   142|   #    NOTE: do NOT call `select-layout tiled` here. It's a no-op for a perfect 2x2
   250|   143|   #    but if any pane is even 1 cell off, tiled will re-compute and may give you
   251|   144|   #    uneven results. Stick with explicit resize-pane.
   252|   145|   #    ON macOS this can fail (one pane collapses to 1 row, opposite takes full column).
   253|   146|   #    If you see uneven sizes after this loop, fall back to pitfall #20's tiled chain:
   254|   147|   #      tmux select-layout -t "$SESSION" even-vertical
   255|   148|   #      tmux select-layout -t "$SESSION" even-horizontal
   256|   149|   #      tmux select-layout -t "$SESSION" tiled
   257|   150|   #    Verified in blocks-mgr-092033 (2026-06-06). Only safe for pure 2xN grids — never
   258|   151|   #    on 1+N Manager+Workers layouts (destructive, see pitfalls #16 and #20).
   259|   152|   for i in 1 2 3 4; do
   260|   153|     tmux resize-pane -t "$SESSION":1.$i -x $PANE_W -y $PANE_H
   261|   154|   done
   262|   155|   sleep 0.5
   263|   156|   # Sanity check: if any pane is < 5 rows tall, the explicit resize-pane failed —
   264|   157|   # apply pitfall #20's tiled chain fallback.
   265|   158|   MIN_H=$(tmux list-panes -t "$SESSION" -F '#{pane_height}' | sort -n | head -1)
   266|   159|   if [ "$MIN_H" -lt 5 ]; then
   267|   160|     tmux select-layout -t "$SESSION" even-vertical
   268|   161|     tmux select-layout -t "$SESSION" even-horizontal
   269|   162|     tmux select-layout -t "$SESSION" tiled
   270|   163|   fi
   271|   164|   148|
   272|   165|   149|# 5. Tag each pane for easy identification
   273|   166|   150|for i in 1 2 3 4; do
   274|   167|   151|  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
   275|   168|   152|done
   276|   169|   153|
   277|   170|   154|# 6. NOW start $AGENT_CMD in each pane (size is stable, prompt_toolkit will fit)
   278|   171|   155|sleep 1
   279|   172|   156|tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
   280|   173|   157|tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p researcher" Enter
   281|   174|   158|tmux send-keys -t "$SESSION":1.3 "$AGENT_CMD -p reviewer" Enter
   282|   175|   159|tmux send-keys -t "$SESSION":1.4 "$AGENT_CMD -p ops" Enter
   283|   176|   160|
   284|   177|   161|# 7. Wait for prompt_toolkit to render, then attach
   285|   178|   162|sleep 6
   286|   179|   163|echo "=== final pane sizes ==="
   287|   180|   164|tmux list-panes -t "$SESSION" -F '  pane #{pane_index} title=#{pane_title} size=#{pane_width}x#{pane_height}'
   288|   181|   165|tmux attach -t "$SESSION"
   289|   182|   166|```
   290|   183|   167|
   291|   184|   168|Expected output: all four panes 99x24 or 100x25 (1-cell off due to borders — that's tmux's natural minimum granularity).
   292|   185|   169|
   293|   186|   170|## Recipe: 6 Panes (2x3 grid) — the next size up
   294|   187|   171|
   295|   188|   172|Same pattern as 2x2, but with `split-window -h` and `split-window -v` called in a different order to build a 2-row × 3-col grid. Even number (6) → perfectly equalisable.
   296|   189|   173|
   297|   190|   174|```bash
   298|   191|   175|SESSION="blocks-6-$(date +%H%M%S)"
   299|   192|   176|
   300|   193|   177|# 1. Explicit session size (must be wide enough for 3 columns)
   301|   194|   178|tmux new-session -d -s "$SESSION" -x 240 -y 50
   302|   195|   179|
   303|   196|   180|# 2. Build 6 empty shells:
   304|   197|   181|#    row 1: pane 1, 2 (split-h)
   305|   198|   182|#    row 2: pane 3, 4, 5, 6 (split-h twice + 2 verticals)
   306|   199|   183|tmux split-window -h -t "$SESSION":1           # panes 1, 2
   307|   200|   184|tmux split-window -v -t "$SESSION":1.1         # pane 3 below pane 1
   308|   201|   185|tmux split-window -v -t "$SESSION":1.2         # pane 4 below pane 2
   309|   202|   186|tmux split-window -h -t "$SESSION":1.3         # pane 5 right of pane 3
   310|   203|   187|tmux split-window -h -t "$SESSION":1.4         # pane 6 right of pane 4
   311|   204|   188|
   312|   205|   189|# 3. Force equal size: 2 rows × 3 cols = each pane 80x25 (240/3 x 50/2)
   313|   206|   190|read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
   314|   207|   191|PANE_W=$((W/3))
   315|   208|   192|PANE_H=$((H/2))
   316|   209|   193|for i in 1 2 3 4 5 6; do
   317|   210|   194|  tmux resize-pane -t "$SESSION":1.$i -x $PANE_W -y $PANE_H
   318|   211|   195|done
   319|   212|   196|
   320|   213|   197|# 4. NO select-layout tiled — keep the explicit 80x25 sizing
   321|   214|   198|#    (tiled is harmless for pure 2x3 grids, but we already have exact sizes)
   322|   215|   199|
   323|   216|   200|# 5. Tag + start $AGENT_CMD
   324|   217|   201|for i in 1 2 3 4 5 6; do
   325|   218|   202|  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
   326|   219|   203|done
   327|   220|   204|sleep 1
   328|   221|   205|for i in 1 2 3 4 5 6; do
   329|   222|   206|  tmux send-keys -t "$SESSION":1.$i "$AGENT_CMD" Enter
   330|   223|   207|done
   331|   224|   208|sleep 6
   332|   225|   209|tmux list-panes -t "$SESSION" -F '  pane #{pane_index} size=#{pane_width}x#{pane_height}'
   333|   226|   210|tmux attach -t "$SESSION"
   334|   227|   211|```
   335|   228|   212|
   336|   229|   213|For 8 panes (2x4 or 4x2), the same pattern: `W/4 x H/2` or `W/2 x H/4` panes.
   337|   230|   214|
   338|   231|   215|## Recipe: 2 Panes (Left/Right or Top/Bottom)
   339|   232|   216|
   340|   233|   217|Even N=2, trivially equal — but still split-shell-first, then $AGENT_CMD:
   341|   234|   218|
   342|   235|   219|**Left/right (2x1):**
   343|   236|   220|```bash
   344|   237|   221|SESSION="blocks-2-$(date +%H%M%S)"
   345|   238|   222|tmux new-session -d -s "$SESSION" -x 200 -y 50
   346|   239|   223|tmux split-window -h -t "$SESSION":1
   347|   240|   224|
   348|   241|   225|# Force equal halves
   349|   242|   226|read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
   350|   243|   227|for i in 1 2; do
   351|   244|   228|  tmux resize-pane -t "$SESSION":1.$i -x $((W/2)) -y $H
   352|   245|   229|done
   353|   246|   230|
   354|   247|   231|# Now start $AGENT_CMD
   355|   248|   232|sleep 1
   356|   249|   233|tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
   357|   250|   234|tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p researcher" Enter
   358|   251|   235|sleep 6 && tmux attach -t "$SESSION"
   359|   252|   236|```
   360|   253|   237|
   361|   254|   238|**Top/bottom (1x2):**
   362|   255|   239|```bash
   363|   256|   240|SESSION="blocks-2v-$(date +%H%M%S)"
   364|   257|   241|tmux new-session -d -s "$SESSION" -x 200 -y 50
   365|   258|   242|tmux split-window -v -t "$SESSION":1
   366|   259|   243|
   367|   260|   244|read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
   368|   261|   245|for i in 1 2; do
   369|   262|   246|  tmux resize-pane -t "$SESSION":1.$i -x $W -y $((H/2))
   370|   263|   247|done
   371|   264|   248|
   372|   265|   249|sleep 1
   373|   266|   250|tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
   374|   267|   251|tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p ops" Enter
   375|   268|   252|sleep 6 && tmux attach -t "$SESSION"
   376|   269|   253|```
   377|   270|   254|
   378|   271|   255|**Variation: 1 agent pane + 1 long-running shell** (e.g. code left, logs right). Same as `Left/right` above but swap the second pane's `$AGENT_CMD` for a long-running command:
   379|   272|   256|
   380|   273|   257|```bash
   381|   274|   258|SESSION="blocks-codelogs-$(date +%H%M%S)"
   382|   275|   259|tmux new-session -d -s "$SESSION" -x 200 -y 50
   383|   276|   260|tmux split-window -h -t "$SESSION":1
   384|   277|   261|# (resize loop as above)
   385|   278|   262|sleep 1
   386|   279|   263|tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder" Enter
   387|   280|   264|tmux send-keys -t "$SESSION":1.2 'tail -f ~/server.log' Enter
   388|   281|   265|sleep 6 && tmux attach -t "$SESSION"
   389|   282|   266|```
   390|   283|   267|
   391|   284|   268|## Recipe: List / Attach / Kill
   392|   285|   269|
   393|   286|   270|```bash
   394|   287|   271|# List all blocks sessions
   395|   288|   272|tmux list-sessions -F '#{session_name}' | grep '^blocks-' || echo "no blocks sessions"
   396|   289|   273|
   397|   290|   274|# Attach to a specific one
   398|   291|   275|tmux attach -t blocks-2x2-143022
   399|   292|   276|
   400|   293|   277|# Kill all blocks sessions
   401|   294|   278|tmux list-sessions -F '#{session_name}' | grep '^blocks-' | xargs -I {} tmux kill-session -t {}
   402|   295|   279|
   403|   296|   280|# Kill just one
   404|   297|   281|tmux kill-session -t blocks-2x2-143022
   405|   298|   282|
   406|   299|   283|# Kill one pane inside a blocks session (e.g. coder is done)
   407|   300|   284|tmux send-keys -t blocks-2x2-143022:1.1 '/exit' Enter
   408|   301|   285|# Pane stays as a dead shell. To remove it:
   409|   302|   286|tmux kill-pane -t blocks-2x2-143022:1.1
   410|   303|   287|```
   411|   304|   288|
   412|   305|   289|## Customisation: Profiles
   413|   306|   290|
   414|   307|   Each pane can use a different profile for total isolation of skills, memory, sessions, and config. The exact mechanism depends on your agent CLI:
   415|   308|
   416|   309|   ```bash
   417|   310|   # hermes (default): create a profile, then launch with -p
   418|   311|   hermes profile create coder --clone default
   419|   312|   hermes profile create researcher --clone default
   420|   313|   # Edit each profile's config independently
   421|   314|   hermes -p coder config set model.default <model>
   422|   315|   hermes -p researcher config set model.default <model>
   423|   316|
   424|   317|   # Other agents: consult their docs for the equivalent. Common patterns:
   425|   318|   #   claude code  →  CLAUDE_CONFIG_DIR=~/.claude-pane-N claude
   426|   319|   #   codex        →  --config <key>=<value> flag or per-pane env
   427|   320|   ```
   428|   321|   300|
   429|   322|   301|If you skip profile creation, just call `$AGENT_CMD` without `-p` — all panes share the default profile, which is fine when you just want multiple windows into the same agent (e.g. one with `--continue` to a long session, others for fresh work). Note: `-p` and profile creation are hermes-specific; consult your agent CLI's docs for the equivalent.
   430|   323|   302|
   431|   324|   303|## Customisation: Per-Pane Startup Prompt
   432|   325|   304|
   433|   326|   305|You can pre-load a task into a pane so the agent starts working immediately. Use `send-keys` after the 6s warm-up, or pass it as the first message via `"$AGENT_CMD" -c <session> -q "..."` in non-interactive mode. For interactive panes, the cleanest trick is to send the prompt after the prompt_toolkit UI is up:
   434|   327|   306|
   435|   328|   307|```bash
   436|   329|   308|sleep 6
   437|   330|   309|tmux send-keys -t "$SESSION":1.1 'Build a FastAPI user service with JWT auth' Enter
   438|   331|   310|```
   439|   332|   311|
   440|   333|   312|## Multi-Repo Code Editing (add -w)
   441|   334|   313|
   442|   335|   314|If multiple panes will edit the same git repo, each pane should work in its own git worktree — prevents index lock conflicts. Add the worktree manually before starting the agent:
   443|   336|   315|
   444|   337|   316|```bash
   445|   338|   317|tmux send-keys -t "$SESSION":1.1 "$AGENT_CMD -p coder"  # -w is hermes-only; do `git worktree add` in pane instead Enter
   446|   339|   318|tmux send-keys -t "$SESSION":1.2 "$AGENT_CMD -p reviewer"  # -w is hermes-only; do `git worktree add` in pane instead Enter
   447|   340|   319|```
   448|   341|   320|
   449|   342|   321|`-w` is hermes-only. For other agents, do `git worktree add <path> -b <branch>` in each pane manually before starting the agent. When done, the user merges worktrees back manually.
   450|   343|   322|
   451|   344|   323|## One-Shot Helpers
   452|   345|   324|
   453|   346|   325|The two Recipes above ([2x2 Default](#recipe-2x2-default-the-canonical-pattern) and [2 Panes](#recipe-2-panes-leftright-or-topbottom)) are the working templates — copy them, swap profile names or paths. The snippets below are quick utilities, not alternative Recipes.
   454|   347|   326|
   455|   348|   327|**Reattach to a previous blocks session:**
   456|   349|   328|```bash
   457|   350|   329|SESSION=$(tmux list-sessions -F '#{session_name}' | grep '^blocks-' | tail -1)
   458|   351|   330|tmux attach -t "$SESSION"
   459|   352|   331|```
   460|   353|   332|
   461|   354|   333|**Cleanup script (drop in ~/.local/bin/blocks-kill-all):**
   462|   355|   334|```bash
   463|   356|   335|#!/bin/bash
   464|   357|   336|tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^blocks-' | while read s; do
   465|   358|   337|  echo "killing $s"
   466|   359|   338|  tmux kill-session -t "$s"
   467|   360|   339|done
   468|   361|   340|```
   469|   362|   341|
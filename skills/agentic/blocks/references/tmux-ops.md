tmux operations: keys, capture-pane, recovery, dynamic pane management, split direction reference. Base-index 1 assumed (see ../templates/tmux.conf.blocks).

### Inside the opened terminal (keys & capture)

After `/blocks` spawns the session, a Terminal window pops open and attaches to it. You see N panes in a grid, one per worker. Here's how to navigate and monitor them.

**Inside the opened terminal** (most common):

| Action | Key |
|--------|-----|
| Move focus to next pane | `Ctrl-b` → `→` / `↓` / `←` / `↑` |
| Click a pane with the mouse | (works with `set -g mouse on`) |
| Zoom current pane to full window, press again to unzoom | `Ctrl-b` `z` |
| Resize by dragging the pane border with the mouse | |
| Detach (keep workers running, return to your shell) | `Ctrl-b` `d` |
| Re-attach from your shell | `tmux attach -t blocks-mgr-XXXXX` |
| List all blocks sessions | `tmux list-sessions \\| grep blocks-` |
| Kill a single session | `tmux kill-session -t blocks-mgr-XXXXX` |

**Detach without killing workers:** `Ctrl-b` then `d` inside the opened terminal. The workers keep running in the background. Re-attach any time with `/blocks attach` or `tmux attach -t <session>`.

**Without attaching** (peek at output programmatically):

```bash
# Capture the last 30 lines of a specific worker's pane
SESSION=blocks-mgr-XXXXX
tmux capture-pane -t "$SESSION":1.1 -p -S -30
# (1.1 = worker-1, 1.2 = worker-2, etc.)

# Capture all workers at once
for i in 1 2 3 4; do
  echo "=== worker-$i ==="
  tmux capture-pane -t "$SESSION":1.$i -p -S -10
done

# Watch a specific worker in real time (10s polling)
watch -n 10 "tmux capture-pane -t $SESSION:1.1 -p -S -20"
```

**Send a follow-up message to one worker** (useful if a worker is stuck or asks a question):

```bash
SESSION=blocks-mgr-XXXXX
tmux send-keys -t "$SESSION":1.2 "continue" Enter
```

The Manager (in your main chat) is also polling `$SHARED/done/` every ~60s and will see results. You don't need to monitor workers constantly — just check in if you're curious or if a worker looks stuck.

**Tip:** `Ctrl-b `z` is the killer feature. Hit it on any pane to fullscreen that one worker's output, hit it again to return to the grid. Great for reading long error logs or big diffs.

### Auto-open: how it works

The `/blocks` command (and the recipe if you call it directly) **automatically opens a new visible terminal window attached to the session** so you can see the workers immediately without copy-pasting a `tmux attach` command. Best-effort per platform:

| Platform | What happens |
|----------|-------------|
| macOS | Writes `/tmp/blocks-attach-<session>.command`, `chmod +x`, then `open`s it. macOS opens it in your default terminal (Terminal.app or iTerm2). |
| Linux | Tries `gnome-terminal` → `konsole` → `alacritty` → `kitty` → `xterm` in order. First one found wins. |
| Other / no terminal | Prints the manual `tmux attach -t <session>` command. You run it yourself. |

The .command file on macOS is also double-clickable from Finder later if you want to re-attach.

### Disable auto-open

If you prefer to attach manually (e.g. you're SSHed into the box and don't have a local terminal to pop open), set the env var `DISABLE_BLOCKS_AUTOOPEN=1` before running `/blocks --manager`:

```bash
DISABLE_BLOCKS_AUTOOPEN=1 /blocks --manager
```

The handler checks for this exact env var name at startup; if set, it skips writing the .command file and printing the attach instructions, and workers keep running headless.

### Recovery from tmux server death (file-based salvage)

If the tmux server dies mid-run (Pitfall 18), the panes are gone but **file changes workers made are already on disk**. The Manager can still salvage the round by scanning the filesystem and writing `summary.md` manually. This is the canonical recovery path — don't try to relaunch the dead session.

```bash
SESSION=blocks-mgr-XXXXX
SHARED="$HOME/blocks-shared/$SESSION"
START_MARKER=/tmp/blocks-mgr-session   # touched at launch

# 1. Confirm the crash (vs. just detached)
tmux list-sessions 2>&1 | grep -q "no server" && echo "TMUX DEAD"

# 2. What workers wrote into the shared dir
ls -la "$SHARED"/{tasks,results,done}

# 3. What workers wrote into the project (exclude build/cache noise)
find <project-root> -newer "$START_MARKER" -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/target/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" | sort

# 4. For each worker, mark status in summary.md:
#    DONE     — all done-conditions met, files present
#    PARTIAL  — some files written, missing pieces
#    BLOCKED  — only 1-2 files or none, was stuck on env issue

# 5. Decide: is the salvage worth a follow-up round, or is the worker
#    productive enough to just hand the result back to the user?
```

The `scripts/recovery-scan.sh` script automates steps 1-3 and prints a status table grouped by expected per-worker domain (the Manager must pass the project root and the per-worker expected paths/globs).

**Why this works without relaunching tmux:** the protocol is deliberately file-based (see the "Why Files, not tmux send-keys" rationale earlier). When tmux dies, the in-memory pane state is gone, but `tasks/`, `results/`, `done/`, and the project's working tree are intact. A 30-second scan recovers ~90% of the work that would otherwise be lost. The remaining 10% is whatever the worker was about to write but hadn't yet fsynced.

**Rule of thumb:** if any worker hit `>=70%` of the round's done-conditions, the salvage is worth using. Dispatch a new round (or hand control back to the user) with the partial work as the new starting point. If a worker is `<30%`, it was probably stuck on environment setup and a fresh round will be more productive than asking for "what they got so far".

### Dynamic Pane Operations

The N you set at launch is just the starting layout. Once the session is running, panes can be added, removed, resized, swapped, and zoomed freely. There are two operators: the user (manual tmux keys) and the Manager (you, the main agent session).

**Manual (you, the user):**

| Key | Action |
|-----|--------|
| `prefix + z` | Zoom current pane to full window (toggle) |
| `prefix + Space` | Cycle layouts: tiled → even-h → even-v → main-h → main-v → tiled |
| `prefix + {` / `}` | Swap with previous/next pane |
| `prefix + x` | Kill current pane (with confirm) |
| `prefix + !` | Break current pane into a new window |
| `prefix + arrow` | Resize by 1 cell (hold for repeat) |
| Mouse drag on border | Resize (with `set -g mouse on`) |
| Click on pane | Focus that pane (with `set -g mouse on`) |

**Programmatic (you, the Manager, via terminal tool):**

You (Manager) can run `tmux` commands via your terminal tool to reshape the worker layout mid-task. Useful when the task scope changes — e.g. "I need to add a 5th worker" or "worker-2 is done, remove it but keep the others".

**Add a new worker pane:**
```bash
SESSION="blocks-mgr-XXXXX"   # your session name
SHARED="$HOME/blocks-shared/$SESSION"

# Get the rightmost pane index
RIGHT=$(tmux list-panes -t "$SESSION" -F '#{pane_index}' | sort -n | tail -1)
NEW=$((RIGHT + 1))

# Split horizontally (new pane to the right of rightmost)
tmux split-window -h -t "$SESSION":1.$RIGHT

# Tag and start
tmux select-pane -t "$SESSION":1.$NEW -T "worker-$NEW"
tmux send-keys -t "$SESSION":1.$NEW "$AGENT_CMD" Enter
sleep 6
tmux send-keys -t "$SESSION":1.$NEW "You are worker-$NEW in $SESSION. Read $SHARED/tasks/worker-$NEW.md. Protocol (REQUIRED): (1) Within 30s of starting: touch $SHARED/done/worker-$NEW-start; (2) do the work, append to results/worker-$NEW.md; (3) when done: touch $SHARED/done/worker-$NEW-final. Start touch = liveness; final touch = finished." Enter

# Re-balance sizes (NO select-layout tiled — it would re-compute the grid)
W=220; H=50
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
COLS=$(echo "$ALL_PANES" | wc -l | tr -d ' ')
PANE_W=$((W / (COLS/2)))
PANE_H=$((H / 2))
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done
```

**Remove a finished worker pane:**
```bash
SESSION="blocks-mgr-XXXXX"
SHARED="$HOME/blocks-shared/$SESSION"

# Graceful: tell it to exit, wait, then kill
PANE=2   # e.g. worker-2
tmux send-keys -t "$SESSION":1.$PANE '/exit' Enter
sleep 3
tmux kill-pane -t "$SESSION":1.$PANE
# Optionally remove its task/result/done files
rm -f "$SHARED/tasks/worker-$PANE.md" "$SHARED/results/worker-$PANE.md" "$SHARED/done/worker-$PANE"

# Re-balance the remaining panes (NO select-layout tiled)
W=220; H=50
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
COLS=$(echo "$ALL_PANES" | wc -l | tr -d ' ')
PANE_W=$((W / (COLS/2)))
PANE_H=$((H / 2))
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done
```

**Re-tag a pane (e.g. promote worker-2 to a specialist role):**
```bash
tmux select-pane -t "$SESSION":1.2 -T "reviewer"
# The pane title in the border updates immediately
```

**Caveats:**
- The Manager has no pane to protect (it's the main chat, not in tmux). You're free to run any tmux command.
- Pane indices shift after splits. After adding one pane, the new one is the highest index, but other indices stay the same.
- `select-layout tiled` is forbidden for 1+N-style adjustments (it would re-compute the grid). For pure N×M grids it's tolerable but unnecessary if you resize-pane explicitly.
- Programmatic changes use up your token budget; don't over-engineer.

## tmux Split Direction Reference

This is the #1 source of bugs in the skill. tmux's split flags are **opposite to vim's intuition**:

| Flag | tmux behaviour | Vim equivalent | Mental model |
|------|----------------|----------------|--------------|
| `split-window -h` | New pane appears **left/right** of target (LEFT/RIGHT split) | `:vsplit` (new pane on the side) | Cut a **vertical** line through the target → 2 cols |
| `split-window -v` | New pane appears **above/below** of target (TOP/BOTTOM split) | `:split` (new pane above/below) | Cut a **horizontal** line through the target → 2 rows |

Most editors call these the opposite (`:vsplit` makes a vertical line = left/right). tmux's `-v` means "split along the vertical axis" = a horizontal cut, which produces top/bottom panes. Don't get caught out.

**Build a 2x2 grid** (TL, TR, BL, BR) by:
1. `split-window -h on 1.1` → 1.1 (left col) | 1.2 (right col)
2. `split-window -v on 1.1` → 1.1 (top-left), 1.3 (bottom-left)
3. `split-window -v on 1.2` → 1.2 (top-right), 1.4 (bottom-right)

**Build a 1+N layout** (1 large + N small stacked) by:
1. `split-window -h on 1.1` → 1.1 (left 50%) | 1.2 (right 50%, full height)
2. `split-window -v` (N-1 more times, each on the latest right-half pane) → 1.2, 1.3, ... 1.(N+1) stacked

**Decision table: when to use `select-layout tiled` (and when not to)**

| Layout | `select-layout tiled`? | Why |
|--------|------------------------|-----|
| Pure N×M grid (2x2, 2x3, 2x4) | Tolerable, but unnecessary | resize-pane gives exact sizes; tiled is fine if you don't need pixel precision |
| 1+N (Manager + Workers) | **NO — destructive** | tiled re-computes the layout and stretches the N small panes into a single column taking the full row |
| After any manual resize-pane | **NO** | tiled overwrites your explicit sizes |

**Rule of thumb:** if you explicitly called `resize-pane` to set pane sizes, don't follow it with `select-layout tiled`. For the canonical split+resize sequence used in the Recipes above, `tiled` is omitted entirely.

**Critical: do NOT call `select-layout tiled` after building a 1+N layout.** It will re-compute the layout and often stretch the N small panes into a single column that takes the full row. For grid layouts (2x2, 3x3) tiled is harmless, but for 1+N it's destructive. Use only `resize-pane` to enforce exact sizes.

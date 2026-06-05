---
layout: default
name: blocks
description: "Use when the user says 'blocks', '分块', '分屏', '2x2', '2*2', '四宫格', '分配N个员工', '起N个worker', 'manager+workers', or types the `/blocks` slash command in a Hermes session. Spawns N Hermes agents in parallel inside a fresh tmux window. Two modes: (1) **flat** — N tmux panes each running an isolated Hermes (N must be even 2/4/6/8, default 2x2); (2) **manager** — the current Hermes chat becomes the Manager (no extra tmux pane), N worker panes spawn in a 2-row × (N/2)-col grid and coordinate via files at ~/blocks-shared/<session>/{tasks,results,done,summary}.md. Both modes equalise pane sizes BEFORE starting Hermes (split shells → resize-pane to even halves → start agents). **Also provides a real hermes slash command** (`/blocks [N|--manager --workers N|list|kill|attach]`) added to `hermes_cli/commands.py` + `cli.py`; inside a Hermes session, `/blocks` and natural-language triggers are equivalent."
version: 1.9.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [tmux, panes, parallel, multi-agent, hermes, workflow, manager, worker, orchestration]
    related_skills: [hermes-agent]
---

# Blocks — Parallel Hermes in tmux Panes

> **Bundled with this skill (verified working as of v1.6.0):**
>
> **Scripts (runnable):**
> - `scripts/blocks` — main CLI: `blocks 4`, `blocks 6 a b c d e f`, `blocks --manager`, `blocks list`, `blocks attach`, `blocks kill`
> - `scripts/blocks.sh` — `.sh` re-export shim of `scripts/blocks` (alias for users who prefer the extension)
> - `scripts/blocks-list.sh` — list active blocks sessions with pane sizes
> - `scripts/blocks-attach.sh` — reattach to most recent (or named) blocks session
> - `scripts/blocks-kill.sh` — kill all or named blocks sessions
> - `scripts/recovery-scan.sh` — post-crash file-based recovery scan: lists what workers actually wrote after a tmux server crash
>
> **Templates (copy & modify):**
> - `templates/tmux.conf.blocks` — recommended `~/.tmux.conf` snippet (mouse on, base-index 1, orange borders, esc-time 0)
>
> **References (read for depth):**
> - `references/worker-execution-protocol.md` — **worker-side playbook**: 30-second start-touch rule, task→execute→final flow, DONE/PARTIAL/BLOCKED status taxonomy, pre-flight env checks, time-budget discipline, BLOCKED-result template
> - `references/tmux-pane-gotchas.md` — 9 deep-dive tmux behaviours with diagnostics: split flag direction, tiled destructiveness, detached size, base-index shift, prompt_toolkit focus, send-keys Enter, mouse reload, attach blocking, kill cascades
> - `references/troubleshooting.md` — symptom→fix index for common blocks problems (layout, mouse, hermes, manager mode, lifecycle, **tmux server crash recovery**)
> - `references/worker-missing-task-protocol.md` — fallback for workers when the Manager never dispatched a task
> - `references/tmux-server-recovery.md` — full procedure for salvaging a manager session after the tmux server dies mid-run (file-based recovery, marking workers PARTIAL/BLOCKED, deciding whether to restart)
> - `references/tmux-server-recovery.md` — full procedure for salvaging a manager session after the tmux server dies mid-run (file-based recovery, marking workers PARTIAL/BLOCKED, deciding whether to restart)

## Overview

One shell command, N parallel Hermes agents side-by-side. The skill wraps tmux split-window + send-keys to spin up an N-pane window where each pane runs an independent Hermes CLI process (optionally a different `-p` profile for full isolation of skills/memory/sessions).

Why panes instead of separate `tmux new-session` calls:
- All agents visible in one viewport — no tab hunting.
- A single tmux prefix key lets you flip between agents.
- Killing the window kills all of them at once.

Default is 2x2 (four panes, tiled) with `coder` / `researcher` / `reviewer` / `ops` profiles. Everything is overridable.

## Quick Start

The full recipes below are ~50 lines of bash each. Pick the one you need, run it from your terminal or have your Hermes session run it via its terminal tool.

```bash
# Flat 2x2 — paste this into a terminal, OR have your Hermes run it via terminal tool
bash -c "$(cat <<'BASH'
SESSION="blocks-2x2-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2
for i in 1 2 3 4; do
  tmux resize-pane -t "$SESSION":1.$i -x 100 -y 25
done
for i in 1 2 3 4; do
  tmux select-pane -t "$SESSION":1.$i -T "pane-$i"
  tmux send-keys -t "$SESSION":1.$i 'hermes' Enter
done
sleep 6 && tmux attach -t "$SESSION"
BASH
)"
```

For the full N-variable, profile-customisable Recipe (with role prompts, sleep waits, error handling), see [Recipe: 2x2 Default](#recipe-2x2-default-the-canonical-pattern) below.

For **Manager mode** the Recipe is at [Recipe: Spawn N Workers in tmux](#recipe-spawn-n-workers-in-tmux-the-only-recipe-blocks---manager-needs) — but the easier path is to just **say** "分配 4 个员工" or "blocks --manager" in your Hermes chat and let this skill handle the rest (see [Invocation Flow](#invocation-flow) below).

For tmux quirks that bite you during blocks debugging (base-index shift, detached size, mouse config, etc.) see the [tmux Split Direction Reference](#tmux-split-direction-reference) and [Common Pitfalls](#common-pitfalls) sections below.

## Even-Number Rule

**N must be even (2, 4, 6, 8).** Odd counts cannot be perfectly equalised in a grid, and `tiled` will give you one stretched pane. If the user asks for an odd N (e.g. 3, 5), bump it up to the next even number and tell them. Common counts:

| N | Layout | Shape |
|---|--------|-------|
| 2 | 1×2 or 2×1 | side by side or stacked |
| 4 | 2×2 | grid (default) |
| 6 | 2×3 or 3×2 | grid |
| 8 | 2×4 or 4×2 | grid |
| > 8 | not recommended | panes get too small for prompt_toolkit |

The "order of operations" is the single most important thing in this skill:

```
1. Create session with explicit -x -y
2. Split into N empty shell panes
3. Force each pane to exact equal size (resize-pane)
4. (For 2xN grids only) optionally select-layout tiled as safety net
5. THEN send-keys 'hermes' to each pane
6. Sleep 6, then attach
```

**Critical:** `select-layout tiled` is safe for square grids (2x2, 2x3, 2x4) but **breaks 1+N structures** (Manager + Workers). For Manager mode, rely on `resize-pane` alone — never call tiled. See Pitfall 16.

Never split + start-hermes in the same loop. prompt_toolkit steals focus and confuses the splitter, leaving you with one tall column and three squished panes.
## When to Use

- User says "blocks 2x2", "分四块", "四宫格", "起 4 个 hermes 并排跑"
- User wants to drive multiple agents in one screen (e.g. one writes code, one researches, one reviews)
- User wants long-running agents in the background but visible
- User wants to A/B compare prompts/models in parallel

Don't use for:
- One quick task → just run `hermes chat -q "..."` directly
- Truly long autonomous missions that don't need a terminal → `hermes chat -q "..."` background, or `cronjob`
- Multiple agents editing the same git repo → add `-w` (worktree) on top of this skill (see Multi-Repo Code below)

## Slash Command (`/blocks` inside a Hermes session)

As of v1.8.0, this skill provides a **real hermes slash command** in addition to natural-language triggers. Inside any Hermes session, typing `/blocks [args]` does the same thing as the corresponding natural-language phrase — but more reliably, because the slash command is registered in `hermes_cli/commands.py` and dispatched through `HermesCLI.process_command` like any built-in command.

**Verified working arguments (all tested with `expect` end-to-end):**

| Slash command | Equivalent to |
|---------------|----------------|
| `/blocks` | 4 flat panes (default) |
| `/blocks 2` | 2 flat panes (1×2) |
| `/blocks 6` | 6 flat panes (3×2) |
| `/blocks 2x2` | 4 flat panes (2×2) |
| `/blocks --manager` | Manager mode, 4 workers |
| `/blocks --manager --workers 6` | Manager mode, 6 workers |
| `/blocks list` | List all `blocks-*` tmux sessions |
| `/blocks kill` | Kill all `blocks-*` tmux sessions |
| `/blocks attach` | Reattach to most recent blocks session (uses `os.execvp` so the calling shell is replaced — proper TTY handoff) |
| `/blocks attach blocks-mgr-140959` | Reattach to a specific session (substring match) |

**Files patched in the hermes source tree** (under `~/.hermes/hermes-agent/`):

1. `hermes_cli/commands.py` — add a `CommandDef`:
   ```python
   CommandDef("blocks", "Spawn N even-sized tmux panes each running an isolated Hermes, or activate Manager mode (...)", "Blocks",
              cli_only=True,
              subcommands=("list", "kill", "attach", "--manager"),
              args_hint="[N|2x2|4|6|8|list|kill|attach|--manager [--workers N]]"),
   ```
   This gives `/help` a clean entry, makes tab-completion work, and lets `resolve_command` find it.

2. `cli.py` — two additions in the `HermesCLI` class:
   - `_handle_blocks_command(self, cmd_original: str)` — parses the args (`/blocks list`, `/blocks --manager --workers 4`, etc.) and dispatches to the right action.
   - `_blocks_spawn_workers(self, n: int, manager_mode: bool = False)` — the actual tmux split + send-keys + role-prompt logic (the equivalent of the `Recipe: Spawn N Workers in tmux` section, but as Python instead of bash).
   - One line in `process_command`: `elif canonical == "blocks": self._handle_blocks_command(cmd_original)`.

**Pinned and load-bearing parts of the patch:**

- The handler runs the verified per-case split sequence (N=2/4/6/8 with `split-window -h`/`-v` in the right order, base-index 1), then forces each pane to `PANE_W x PANE_H` via `resize-pane` — never `select-layout tiled` (Pitfall 16).
- `select-layout tiled` is **deliberately absent** from the slash command handler. It would re-compute the grid destructively.
- The handler sleeps 1s then 6s around the `send-keys` calls (Pitfall 6, "race condition on send-keys" → prompt_toolkit needs ~5-7s to render).
- The "Manager mode activated" banner is printed as plain `print()` (not `cprint`) so it's greppable from `~/.hermes/logs/agent.log`.
- Round-up of odd N to the next even happens BEFORE the `if/elif` split-sequence dispatch, so the N=2/4/6/8 dispatch always gets a valid N.

**⚠️ Regresssion risk:** the patch lives in `~/.hermes/hermes-agent/` which is the working tree of a git checkout. Running `hermes update` will pull upstream and overwrite it. Two ways to protect the work:
- Commit the patch to a fork of `hermes-agent` and reinstall from that fork.
- Save the diff: `cd ~/.hermes/hermes-agent && git diff cli.py hermes_cli/commands.py > ~/.hermes/patches/blocks-slash-command.patch`, then re-apply after update with `git apply`.

**Why natural-language triggers are still valuable** even with the slash command: the slash command only works *inside* a Hermes session. If the user wants to spawn blocks from a plain terminal (not in a chat), the natural-language path doesn't help either — they need to run the bash from the `Recipe: 2x2 Default` section, or `bash ~/.hermes/skills/blocks/scripts/blocks.sh` if a script is available.

## Syntax

The user invokes it conversationally. Parse the intent and call the matching recipe.

| User says | Action |
|-----------|--------|
| `blocks` / `分块` | 2x2 default (coder, researcher, reviewer, ops) |
| `blocks 2x2` / `blocks 2*2` / `4 个` / `四宫格` | 2x2 default profiles |
| `blocks 2` / `blocks 2x1` / `左右两个` | 2 panes, even-vertical |
| `blocks 1x2` / `blocks 2v` / `上下两个` | 2 panes, even-horizontal |
| `blocks 6` / `6 个` | 2x3 grid, tiled |
| `blocks 4 coder designer writer pm` | 2x2 with custom profile names |
| `blocks 3x2` | 3 cols × 2 rows (6 panes) |
| `blocks list` | show all `blocks-*` tmux sessions |
| `blocks attach` / `blocks attach blocks-2x2` | tmux attach to a blocks session |
| `blocks kill` / `blocks stop` / `blocks 收工` | kill all `blocks-*` sessions |
| `blocks kill coder` | kill only the coder pane in current window |
| `blocks --manager` / `blocks --manager --workers 4` / `分配 4 个员工` | Activate Manager mode + spawn 4 worker panes in 2x2 grid |
| `blocks --manager --workers 6` / `分配 6 个员工` | Activate Manager mode + spawn 6 worker panes in 3x2 grid |
| `blocks --manager --workers 2` / `分配 2 个员工` | Activate Manager mode + spawn 2 worker panes in 1x2 grid |
| `blocks --manager --workers N` / `分配 N 个员工` | N must be even (2/4/6/8); if user says odd N, round up and tell them |
| `/blocks` (slash command, inside a Hermes session) | 4 flat panes (default) — equivalent to `blocks 4` |
| `/blocks 2` / `/blocks 6` / `/blocks 2x2` (slash command) | N flat panes — equivalent to `blocks N` or `blocks 2x2` |
| `/blocks --manager` (slash command) | Activate Manager mode with 4 workers |
| `/blocks --manager --workers 6` (slash command) | Activate Manager mode with 6 workers |
| `/blocks list` (slash command) | List all `blocks-*` tmux sessions |
| `/blocks kill` (slash command) | Kill all `blocks-*` tmux sessions |
| `/blocks attach` (slash command) | Reattach to the most recent blocks session (replaces the calling shell via `os.execvp`) |

**Odd N (3, 5, 7):** round up to the next even number and tell the user. `blocks 3` → silently becomes `blocks 4` and warn. `blocks 5` → `blocks 6`, etc.

Profile fallback: if a requested profile doesn't exist, fall back to default profile (no `-p` flag) rather than failing.

## Manager/Worker Mode (`blocks --manager`)

For tasks that benefit from a coordinating brain and N parallel hands: the user gives a single task, the **current Hermes session becomes the Manager**, breaks the task into N sub-tasks, dispatches them to N Workers (which run in tmux panes), watches for results, aggregates, and reports back to the user in the main chat.

**The Manager is the current chat, not a tmux pane.** This is the key design choice: the user is always talking to the Manager, in the main Hermes conversation. The N workers live in tmux panes so the user can visually monitor their progress. No need to switch focus to a "manager pane" — there is no such pane.

### Invocation Flow (read this first if you are the Manager)

You (this Hermes session) are about to become the Manager. Here is the exact flow:

```
USER TRIGGERS                  HERMES DOES
─────────────────────────────────────────────────────────────────────
"blocks --manager"          →   Run the Recipe in section
                                 "Recipe: Spawn N Workers in tmux"
                                 via terminal tool.
                                 The Recipe outputs:
                                   "✓ Manager mode activated.
                                    Session: blocks-mgr-XXXXX
                                    Workers: N panes in tmux session ...
                                    Shared: /Users/ejuer/blocks-shared/..."

                               →   Acknowledge to the user:
                                    "Manager mode is on. N workers spawned.
                                     Send me the task."

USER: "把 X 跑通并对比 baseline"
                              →   Save verbatim to $SHARED/task.md
                               →   Break into N sub-tasks, write to
                                   $SHARED/tasks/worker-N.md
                               →   Tell the user the plan in chat
                               →   Poll $SHARED/done/ every ~60s

(workers in tmux do their work, write results, touch done files)

                              →   When all done-files exist:
                                   Read results/worker-*.md, write
                                   $SHARED/summary.md, paste summary
                                   in chat.

USER: "kill it"              →   `blocks kill` (or just tell user to
                                 run it themselves)
```

**Triggers that activate Manager mode** (any of these in the user's message):

- `blocks --manager` — default 4 workers
- `blocks --manager --workers N` — N workers (N must be even, else round up)
- `blocks --manager --workers 6` — explicit N
- `分配 4 个员工` / `分配 6 个员工` / `分配 N 个员工` — Chinese
- `起 4 个 worker` / `起 N 个 worker` / `起 4 个 hermes` — Chinese variant
- `manager+workers` / `manager mode` / `4 panes with manager` — English variants
- `我要 manager` / `manager 模式` / `拆给 4 个员工做` — semantic variants

When you see any of these, **execute the Recipe in your terminal tool**. The Recipe's last output is the "Manager mode activated" banner. After printing the banner, **you ARE the Manager** — from this point on, every user message is a task for the Manager role.

> **Chunking hint (read this first):** the default 10-minute per-worker timeout is the *upper bound*, not a target. On macOS, fully-detached tmux servers can be reaped by launchd after 10+ minutes — see Pitfall 19. Split work into **5-7 minute rounds** with explicit `done/` signalling, and either attach to the tmux session after spawning (so launchd treats it as user-attached) or be ready to recover from the filesystem if it dies. See `references/tmux-server-recovery.md`.

**Critical: do NOT just describe the workflow as text.** You must actually `tmux new-session`, `tmux send-keys`, and `mkdir` etc. via the terminal tool. The Recipe has the exact bash. Run it, then become the Manager.

### Layout

```
┌─────────┬─────────┬─────────┐
│ Worker 1│ Worker 2│         │
│ (top)   │ (top)   │  ...    │  N panes in a grid
├─────────┼─────────┼─────────┤
│ Worker 3│ Worker 4│         │
│ (bottom)│ (bottom)│         │
└─────────┴─────────┴─────────┘

N=2: 1 col × 2 rows      N=6: 3 cols × 2 rows
N=4: 2 cols × 2 rows     N=8: 4 cols × 2 rows
```

Workers form a 2-row × (N/2)-col grid in a fresh tmux window. N must be even (2/4/6/8). The user is NOT in the tmux session by default — the workers are visible, but the user interacts with the Manager from the main chat. (You can `tmux attach` to the session if you want to see it directly, or use `blocks attach`.)

### Communication Protocol (file-system based)

```
~/blocks-shared/<session-name>/
├── task.md                    # The user's original task (Manager writes here)
├── plan.md                    # Manager writes its plan here
├── tasks/
│   ├── worker-1.md            # Sub-task dispatched to worker-1
│   ├── worker-2.md
│   ├── worker-3.md
│   └── worker-4.md
├── results/
│   ├── worker-1.md            # Worker-1 writes its result here
│   ├── worker-2.md
│   └── ...
├── done/
│   ├── worker-1               # `touch` = worker-1 finished
│   ├── worker-2
│   └── ...
└── summary.md                 # Manager aggregates here when all done
```

**Why files, not tmux send-keys:** Manager is an LLM, not a deterministic controller. Telling it "use send-keys to dispatch tasks" makes the LLM responsible for tmux syntax, pane indexing, and race conditions. Files are simple, idempotent, inspectable, and survive Manager restarts. They also let the user inspect the system state at any time via `ls ~/blocks-shared/<session>/`.

### What Each Worker Knows (delivered as first message after hermes starts)

```
You are worker-N in blocks session <SESSION>.

Your sub-task: read ~/blocks-shared/<SESSION>/tasks/worker-N.md

Protocol (REQUIRED — protects against tmux server crash, see Pitfall 19):
  1. **WITHIN 30 SECONDS** of starting: `touch ~/blocks-shared/<SESSION>/done/worker-N-start`
     This signals "I started." If the tmux server dies mid-task, the manager can
     still see the worker received the task. Without this file, the manager
     assumes the worker never started.
  2. Execute your sub-task from the task file
  3. Write your final result to `~/blocks-shared/<SESSION>/results/worker-N.md`
  4. `touch ~/blocks-shared/<SESSION>/done/worker-N-final`

Do not start any work that is not in your task file. Do not touch other workers' files.
If you need help, write a question to results/worker-N.md and stop.
```

### What the Manager Knows (this is YOU, the current Hermes session)

When the user invokes `blocks --manager` or "分配 N 个员工", the recipe spawns N workers in tmux and outputs an activation message. **You (this Hermes) become the Manager.** From this point on, every user message in this chat is a task or follow-up for the Manager role.

**Manager protocol (read this carefully):**

```
You are the manager in blocks session <SESSION>.

You have N workers: worker-1 ... worker-N. They are running in tmux session <SESSION>.

Your job:
  1. The user will paste a task into this chat. Save it verbatim to:
     ~/blocks-shared/<SESSION>/task.md
  2. Break the task into N sub-tasks (one per worker, or fewer with some marked SKIPPED).
     For each worker-i, write to ~/blocks-shared/<SESSION>/tasks/worker-i.md
  3. Save your overall plan to ~/blocks-shared/<SESSION>/plan.md
  4. Poll for completion: every 60s run `ls ~/blocks-shared/<SESSION>/done/`
     When all expected worker files exist, proceed.
  5. Read results/worker-*.md, aggregate, write ~/blocks-shared/<SESSION>/summary.md
  6. Report the summary to the user directly in this chat.

Timeout: 5-6 minutes per worker. Longer windows (10+ min) risk the macOS tmux
server crashing mid-round, killing all workers with no recovery — see
references/macos-tmux-crash-recovery.md and Pitfall 19. If `done/worker-N-start`
exists but `done/worker-N-final` is missing past 6 min, treat the worker as
stalled. After timeout, report the stalled worker to the user and ask whether
to continue waiting or proceed without them.

You can see the workers' tmux panes in tmux session <SESSION>. The user can
attach via `tmux attach -t <SESSION>` to watch them. If a worker stalls, you
may nudge it via `tmux send-keys -t <SESSION>:1.<pane> 'message' Enter` — but
the canonical coordination is via the file system.
```

**Activation message format (printed by blocks script):**

```
✓ Manager mode activated.
  Session:   blocks-mgr-135421
  Workers:   4 panes in tmux session blocks-mgr-135421
  Shared:    /Users/ejuer/blocks-shared/blocks-mgr-135421
  Protocol:  $SHARED/tasks/ for sub-tasks, $SHARED/done/ for completion signals

Tell me your task. I will break it into N sub-tasks, dispatch to workers,
poll for results, and report back here.
```

When the user sees this, they know Manager mode is active. They reply with a task, you (this Hermes) follow the protocol.

### Launch Command

```bash
blocks --manager              # 4 workers in 2x2 grid (default)
blocks --manager --workers 6  # 6 workers in 3x2 grid
blocks --manager --workers 2  # 2 workers in 1x2 grid
```

The user invokes this naturally:
- `blocks --manager` (or `分配 4 个员工`, `起 4 个 worker`, `4 panes with manager`)
- `blocks --manager --workers 6` (or `分配 6 个员工`, `6 panes with manager`)

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
On done: write $SHARED/results/worker-$i.md, then touch $SHARED/done/worker-$i."
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

### End-to-End Usage

1. You're in the main Hermes chat. You say: "blocks --manager --workers 4" (or "分配 4 个员工", or "起 4 个 worker").
2. The current Hermes (you) executes the blocks recipe, which spawns 4 tmux panes (workers) in a new session, injects their roles, and prints the activation message.
3. You reply with a task: "把 HyperGraphRAG 跑通并对比 baseline".
4. The current Hermes (now in Manager mode) saves your task to `$SHARED/task.md`, breaks it into 4 sub-tasks, writes them to `$SHARED/tasks/worker-*.md`, and tells you the plan in the chat.
5. The 4 workers pick up their tasks, do the work, write results to `$SHARED/results/worker-*.md`, and `touch` `$SHARED/done/worker-*`.
6. The Manager (you) polls `$SHARED/done/` every 60s. When all 4 are done, you read the results, write `$SHARED/summary.md`, and report the summary to the user right here in the chat.
7. The user can `tmux attach -t <session>` to watch the workers live, but doesn't have to. The conversation here is the source of truth.

### Auto-open a visible terminal (after spawn)

The `/blocks` command (and the recipe if you call it directly) **automatically opens a new visible terminal window attached to the session** so you can see the workers immediately without copy-pasting a `tmux attach` command. Best-effort per platform:

| Platform | What happens |
|----------|-------------|
| macOS | Writes `/tmp/blocks-attach-<session>.command`, `chmod +x`, then `open`s it. macOS opens it in your default terminal (Terminal.app or iTerm2). |
| Linux | Tries `gnome-terminal` → `konsole` → `alacritty` → `kitty` → `xterm` in order. First one found wins. |
| Other / no terminal | Prints the manual `tmux attach -t <session>` command. You run it yourself. |

The .command file on macOS is also double-clickable from Finder later if you want to re-attach.

**Detach without killing workers:** `Ctrl-b` then `d` inside the opened terminal. The workers keep running in the background. Re-attach any time with `/blocks attach` or `tmux attach -t <session>`.

**Disable auto-open** (if you prefer to attach manually): wrap the call in your shell:
```bash
DISABLE_BLOCKS_AUTOOPEN=1 /blocks --manager
```
The handler respects this env var (currently honoured by the recipe's own checks; see [Pitfall](#common-pitfalls) for the gate variable name).

### Recovery from tmux server death (file-based salvage)

If the tmux server dies mid-run (Pitfall 19), the panes are gone but **file changes workers made are already on disk**. The Manager can still salvage the round by scanning the filesystem and writing `summary.md` manually. This is the canonical recovery path — don't try to relaunch the dead session.

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

### Worker Execution Protocol (the canonical happy path)

The role prompt sent to each worker pane is intentionally short (4 lines). The **full worker-side playbook** — the 30-second start-touch rule, the task→execute→final flow, the DONE/PARTIAL/BLOCKED status taxonomy, pre-flight environment checks, and time-budget discipline — lives in [`references/worker-execution-protocol.md`](references/worker-execution-protocol.md).

**If you are a worker:** read that reference as your first action after the role prompt lands. The 30-second start-touch (`touch $SHARED/done/worker-N-start`) MUST happen before you read the task file — the Manager has no other signal that your pane is alive.

**If you are the Manager:** link the worker to that reference in your dispatch message (or trust the worker's own knowledge of this skill) so the worker knows the full protocol.

### Edge Cases

| Case | Handling |
|------|----------|
| Task is too small to split into N | Manager writes SKIPPED.md in extra workers' task files, they exit cleanly |
| Worker stalls (no done-file in 10 min) | Manager reports which worker is stuck, asks user |
| Manager (you) gets stuck or confused | User can just re-prompt you: "skip worker-2, give me what you have" |
| Need to add workers mid-task | Use `tmux split-window` to add a pane, send the role prompt. See Dynamic Pane Operations below. |
| Workers need to collaborate | They don't talk directly. They write questions to their result file; Manager arbitrates on the next poll. |

### Why No Auto-Watch

A `fswatch`/`inotifywait` watcher that pushes "worker-X done!" into the Manager (you) would save polling, but:
- Adds an external dep (`fswatch` on macOS, `inotify-tools` on Linux)
- The Manager still has to read the result file anyway, so polling is the same cost
- LLM polling is robust: if a poll fails, the next one catches it

If you want auto-watch later, add a `blocks --manager --watch` flag and a tiny fswatch wrapper that interrupts the Manager's normal tool loop with a "worker-X done!" message.

### Kill a Manager Session

`blocks kill` tears down the whole tmux session (and all its workers). The shared directory at `~/blocks-shared/<session>/` is left in place for inspection; delete it manually if not needed.

The Manager role in the main chat does NOT auto-exit when the workers are killed. After `blocks kill`, you can keep talking and the Manager will just notice the workers are gone.

### Dynamic Pane Operations

The N you set at launch is just the starting layout. Once the session is running, panes can be added, removed, resized, swapped, and zoomed freely. There are two operators: the user (manual tmux keys) and the Manager (you, the main Hermes session).

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
tmux send-keys -t "$SESSION":1.$NEW 'hermes' Enter
sleep 6
tmux send-keys -t "$SESSION":1.$NEW "You are worker-$NEW in $SESSION. Read $SHARED/tasks/worker-$NEW.md. On done: write $SHARED/results/worker-$NEW.md, then touch $SHARED/done/worker-$NEW." Enter

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
2. `split-window -v on 1.2` (N-1 more times, each on the latest right-half pane) → 1.2, 1.3, ... 1.(N+1) stacked

**Critical: do NOT call `select-layout tiled` after building a 1+N layout.** It will re-compute the layout and often stretch the N small panes into a single column that takes the full row. For grid layouts (2x2, 3x3) tiled is harmless, but for 1+N it's destructive. Use only `resize-pane` to enforce exact sizes.

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

## Common Pitfalls

1. **Odd N cannot be perfectly equalised** — `blocks 3` / `blocks 5` will give you one stretched pane because tiled can't tile an odd count in a grid. Round up to the next even number and warn the user. (See Even-Number Rule above.)

2. **Splitting + starting Hermes in the same step** — the #1 cause of uneven layouts. Always split empty shells first, resize to equal, *then* `send-keys 'hermes'`. prompt_toolkit's TUI interferes with tmux's split heuristics if it's running while you split.

3. **Panes too small** — Hermes wraps long diffs/tables in tiny panes. For 2x2 use `-x 200 -y 50` minimum. For 2x3 use `-x 240 -y 50`. For 2x4 use `-x 320 -y 50`. If the user's terminal is smaller than that, drop to 2x1.

4. **Detached sessions have no size** — `tmux list-sessions -F '#{session_width}'` returns empty for a `-d` session. Always pass `-x W -y H` explicitly to `new-session`, otherwise step 3 (resize-pane) computes zero-sized panes.

5. **`base-index 1` shifts everything** — if `~/.tmux.conf` sets `set -g base-index 1` and `setw -g pane-base-index 1` (recommended for blocks), the first window is `:1` and the first pane is `:1.1`, not `:0.0`. All references in this skill assume base-index 1. If you remove it from your config, change all `:1.$i` back to `:0.$i`.

6. **Race condition on `send-keys`** — `prompt_toolkit` needs ~5-7 seconds to render the input box. Always `sleep 6` after sending `hermes` and before attaching. Without it, the keys land before the prompt is ready and get lost.

7. **Forgetting `Enter` after `send-keys`** — `tmux send-keys` does NOT press Enter by default. Always end with `Enter`.

8. **`attach` blocks the calling shell** — that's expected. The user is now inside tmux. Detach with `prefix + d` (default prefix is `Ctrl-b`).

9. **Killing the window from inside tmux** — `prefix + &` (with confirm) or `prefix + x` for the current pane. Either kills Hermes without graceful `/exit`. Prefer `prefix + d` to detach and let users resume with `blocks attach`.

10. **Panes numbered by creation order, not visual position** — after `tiled` layout, pane 1.1 may end up bottom-left, not top-left. Address by number, not position. Use `select-pane -T` to tag them with meaningful names if you need stable identifiers.

11. **Profile doesn't exist → silent fallback to default** — if the user says `-p coder` but the profile wasn't created, Hermes runs without isolation. Warn the user the first time a non-existent profile is requested.

12. **Stale sessions pile up** — `tmux list-sessions | grep blocks-` can show 10 zombie sessions. Use `blocks kill` to clean up.

13. **tmux not installed** — `brew install tmux` on macOS, `apt install tmux` on Linux. `blocks` should check this first and fail loud with the install command.

14. **TERM variable** — Hermes via prompt_toolkit needs `$TERM` set to something like `xterm-256color` or `screen-256color`. If the user is inside an old SSH session with `dumb`, rendering breaks. Suggest `export TERM=xterm-256color` before re-running.

15. **Mouse support** — by default tmux does NOT pass mouse events to panes. Without `set -g mouse on` in `~/.tmux.conf`, the user can't click to switch panes, drag borders to resize, or use the wheel to scroll history. blocks depends on this; if the user complains about "can't click", the first thing to check is tmux mouse config. The `templates/tmux.conf.blocks` snippet enables this and other recommended settings.

16. **`select-layout tiled` is destructive on 1+N layouts** — when you have 1 large pane (Manager) + N small panes (Workers), calling `select-layout tiled` afterwards will RE-COMPUTE the layout using tmux's tiled algorithm. With 3 total panes, tiled often produces "1 large left + 1 column-right that takes the full row" — completely losing the N-pane stack. Pure grid layouts (2x2, 3x3) are tolerant of tiled, but for Manager+Workers structures, ALWAYS use only `resize-pane` to enforce sizes and skip `select-layout tiled` entirely. See `references/tmux-pane-gotchas.md` § 2 for the full diagnostic.

17. **tmux split flags are OPPOSITE of vim** — `tmux split-window -h` does a **left/right** split (new pane to the right of target). `tmux split-window -v` does a **top/bottom** split (new pane below target). The names refer to the **line orientation**, not the split direction. This is opposite of vim's `:split` (top/bottom) and `:vsplit` (left/right). Easy way to remember: `Ctrl-b + "` (double-quote key, "horizontal line" icon) is `-h` = horizontal line = L/R split. `Ctrl-b + %` (percent key, "vertical line" icon) is `-v` = vertical line = T/B split. All Recipes in this skill assume this convention. See `references/tmux-pane-gotchas.md` § 1.

18. **`hermes chat` has no `--system-note` flag** — earlier drafts of this skill assumed a flag like `hermes --system-note '...'` could inject a role prompt at startup. It doesn't exist. The verified working pattern is: send `hermes` to the pane, wait 6s for prompt_toolkit to render, then send the role text as the first user message via `tmux send-keys -t "$SESSION":1.$i "You are ..." Enter`. The role then becomes the first entry in the conversation history, which the agent sees and obeys.

19. **macOS tmux server crashes after ~10 minutes of detached running** — On macOS Sonoma/Sequoia, a `tmux new-session -d` session that holds 4 hermes workers (each compiling/running tests, doing heavy shell work) can crash the entire tmux server around the 10-11 minute mark. Symptoms: `tmux list-sessions` returns `no server running on /private/tmp/tmux-501/default`, all worker hermes subprocesses vanish, pane capture returns blank. **This is NOT recoverable** — the workers and their in-memory state are gone. See `references/macos-tmux-crash-recovery.md` for the full diagnosis and protocol. **Mitigations baked into the skill**:
    - Cap single-round task time at **5-6 minutes** (not the 10-min default the recipe used to suggest)
    - Workers must **`touch done-start` within 30s** of starting — that file is the only post-mortem signal that the worker received and began the task
    - Workers must **write incremental progress into `results/worker-N.md`** even before done-final — a worker that has already written a header + first finding to the result file gives the manager usable output even if the final touch is never reached
    - If the manager needs more than 5-6 min of work per round, **split into multiple rounds** rather than extending the timeout

19. **macOS can reap a fully-detached tmux server after 10+ minutes** — `tmux list-sessions` suddenly returns `no server running on /private/tmp/tmux-501/default` and all worker panes are gone. macOS launchd may treat the detached server as abandoned under memory pressure or after a sleep/wake cycle. Symptoms on the manager side: `tmux capture-pane` and `tmux send-keys` both fail with "no server". The good news: file changes workers made have already been written to disk and survive the crash — only the panes are lost.
    **Fix:**
    - Don't rely on a single 10+ minute round. Split the task into **5-7 minute rounds** with explicit `done/` signals between rounds. The Manager can poll between rounds, see who finished, and dispatch a follow-up round.
    - After spawning the session, attach to it (or open a `tmux attach` window). launchd is much less aggressive about reaping sessions with a live client.
    - If a crash does happen, see Pitfall 20 + the **Recovery from tmux server death** subsection below.

20. **Worker should `touch $SHARED/done/worker-N` BEFORE writing `results/worker-N.md`, not after** — if the worker writes the result first, then crashes (or the tmux server dies) before touching `done/`, the manager polls forever and times out, even though the result file actually exists. The atomic signal must precede the (slow) result write.
    **Fix:** in every task file's "completion protocol" section, write:
    > **Order matters**: 1. start writing the result to `results/worker-N.md` (it can be partial — keep appending); 2. as soon as you begin, `touch $SHARED/done/worker-N`; 3. finish writing the result. The `done/` touch is the atomic signal — write it FIRST, refine the result AFTER. If you crash mid-write, the manager can still recover your partial result.
    The Manager should also treat "result file exists with recent mtime but no `done/`" as a stalled worker and either nudge via `tmux send-keys` (if tmux is alive) or mark PARTIAL and read the result file directly (if tmux is dead).

21. **`resize-pane -x W -y H` after a fresh `split-window` is sometimes a no-op on macOS tmux** — one pane ends up 109x1 (squashed to 1 row) and the opposite pane takes 110x50 (the full column). This is a known tmux bug pattern when the second `split -v` is issued on a pane that has been re-balanced by a previous split.
    **Fix (verified working for 2xN pure grids):** after the splits, chain layout engines to force re-tiling:
    ```bash
    tmux select-layout -t "$SESSION" even-vertical
    tmux select-layout -t "$SESSION" even-horizontal
    tmux select-layout -t "$SESSION" tiled
    ```
    This is safe for 2x2 / 2x3 / 2x4 pure grids. **Do NOT use this chain on a 1+N Manager+Workers structure** — `tiled` is destructive there (Pitfall 16). For 1+N, stick with explicit `resize-pane` only.

22. **`#{session_width}` and `#{session_height}` return empty for a freshly-detached session** — `read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)` gives empty values, and any `resize-pane -x 0 -y 0` based on it is a no-op (pane collapses to 0).
    **Fix:** always **hardcode** the same dimensions you passed to `tmux new-session -x W -y H`. Don't try to read them back from a detached session. For 2x2 with `-x 220 -y 50`, the target pane size is `110x25` (border cells eat ~1-2 from each).

23. **Multi-round sessions need TWO touch files, not one** — the single `done/worker-N` touch protocol works for round 1 of a session, but round 2+ of the same `--manager` blocks session hits an ambiguity:
    - No `done/` file after N minutes → is the worker pane still alive and just slow, or did it die between rounds?
    - If it died, the Manager has no idea how far the worker got (was it reading the task, halfway through coding, or about to write the result?).
    **Fix (verified working, blocks-mgr-144650 round 2, 2026-06-05):** the task file for round-N+ workers should mandate TWO touches:
    ```bash
    # Within 30 seconds of reading the task file (heartbeat — proves the pane is alive and the worker has context)
    touch ~/blocks-shared/<session>/done/worker-N-start

    # ... do the work, write results/worker-N.md ...

    # Last step, signals "I'm done, read my result"
    touch ~/blocks-shared/<session>/done/worker-N-final
    ```
    The Manager can then tell three states apart:
    - **No start, no final** → pane is dead or never read the task
    - **Start present, no final** → worker is alive and working (or crashed mid-round)
    - **Both present** → worker finished; read the result

    The `worker-N-start` file should be touched BEFORE any heavy work, and the task file should say "CRITICAL: first action MUST be ... touching .../done/worker-N-start within 30 seconds. This protects against tmux server crash — without that touch file the manager will assume you never started." The 30-second deadline also catches the case where the worker is stuck reading/parsing the task file.

23. **`/blocks` slash command is gone after `hermes update`** — the patch that adds the CommandDef + handler lives in `~/.hermes/hermes-agent/{hermes_cli/commands.py,cli.py}`, which is the upstream working tree. `hermes update` overwrites it. Symptoms: `/blocks` returns "Unknown command: /blocks" in newer sessions.
    **Fix (before running update):**
    ```bash
    cd ~/.hermes/hermes-agent
    git diff cli.py hermes_cli/commands.py > ~/.hermes/patches/blocks-slash-command.patch
    ```
    **Fix (after running update):**
    ```bash
    cd ~/.hermes/hermes-agent
    git apply ~/.hermes/patches/blocks-slash-command.patch
    ```
    Permanent fix: maintain a fork of `hermes-agent` with the patch applied, and reinstall `hermes` from your fork. See the "Slash Command" section above for the exact files and the pin-worthy lines to keep.

## Verification Checklist

After running a `blocks N` command, confirm:

- [ ] `tmux list-sessions | grep blocks-` shows the new session
- [ ] `tmux list-panes -t <session> -F '#{pane_index}' | wc -l` equals N (and N is even)
- [ ] `tmux list-panes -t <session> -F '#{pane_width}x#{pane_height}'` shows panes within 1 cell of each other (uniform layout)
- [ ] Each pane shows a Hermes prompt (not a blank shell or `command not found`)
- [ ] Typing into a pane is accepted by the Hermes prompt (not echoed raw to shell)
- [ ] Mouse click switches pane focus (requires `set -g mouse on` in `~/.tmux.conf`)
- [ ] `prefix + d` detaches cleanly, `blocks attach <session>` reattaches
- [ ] If profiles were requested, `hermes profile list` shows them

## One-Shot Recipes

**Quick 2x2 with custom task per pane:**
```bash
SESSION="blocks-2x2-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1
tmux split-window -v -t "$SESSION":1.1
tmux split-window -v -t "$SESSION":1.2

# Force equal
read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
for i in 1 2 3 4; do
  tmux resize-pane -t "$SESSION":1.$i -x $((W/2)) -y $((H/2))
done
# NO select-layout tiled

# Start hermes
sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'hermes -p researcher' Enter
tmux send-keys -t "$SESSION":1.3 'hermes -p reviewer' Enter
tmux send-keys -t "$SESSION":1.4 'hermes -p ops' Enter

# Auto-load tasks after prompt_toolkit is up
sleep 6
tmux send-keys -t "$SESSION":1.1 'Refactor auth middleware to use FastAPI dependencies' Enter
tmux send-keys -t "$SESSION":1.2 'Research: best Python lib for JWT in 2026' Enter
tmux send-keys -t "$SESSION":1.3 'Review the PR #142 diff' Enter
tmux send-keys -t "$SESSION":1.4 'Check server CPU/mem every 30s and report' Enter
tmux attach -t "$SESSION"
```

**Side-by-side: code left, logs right:**
```bash
SESSION="blocks-codelogs-$(date +%H%M%S)"
tmux new-session -d -s "$SESSION" -x 200 -y 50
tmux split-window -h -t "$SESSION":1

read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)
for i in 1 2; do
  tmux resize-pane -t "$SESSION":1.$i -x $((W/2)) -y $H
done

sleep 1
tmux send-keys -t "$SESSION":1.1 'hermes -p coder' Enter
tmux send-keys -t "$SESSION":1.2 'tail -f ~/server.log' Enter
sleep 6 && tmux attach -t "$SESSION"
```

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

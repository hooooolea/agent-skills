Full Manager + Worker protocol. SKILL.md has the compressed version; this is the long form. Pitfall numbers referenced here resolve in ../pitfalls.md.

### Invocation Flow (read this first if you are the Manager)

You (this agent session) are about to become the Manager. Here is the exact flow:

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
- `起 4 个 worker` / `起 N 个 worker` / `起 4 个 $AGENT_CMD` — Chinese variant
- `manager+workers` / `manager mode` / `4 panes with manager` — English variants
- `我要 manager` / `manager 模式` / `拆给 4 个员工做` — semantic variants

When you see any of these, **execute the Recipe in your terminal tool**. The Recipe's last output is the "Manager mode activated" banner. After printing the banner, **you ARE the Manager** — from this point on, every user message is a task for the Manager role.

> **Chunking hint (read this first):** the default 10-minute per-worker timeout is the *upper bound*, not a target. On macOS, fully-detached tmux servers can be reaped by launchd after 10+ minutes — see Pitfall 18. Split work into **6-minute rounds** (hard upper bound 7 min) with explicit `done/` signalling, and either attach to the tmux session after spawning (so launchd treats it as user-attached) or be ready to recover from the filesystem if it dies. See `references/tmux-server-recovery.md`.

**Critical: do NOT just describe the workflow as text.** You must actually `tmux new-session`, `tmux send-keys`, and `mkdir` etc. via the terminal tool. The Recipe has the exact bash. Run it, then become the Manager.

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
│   ├── worker-1-start         # `touch` within 30s = liveness signal (pane received task)
│   ├── worker-1-final         # `touch` when done = result is ready to read
│   ├── worker-2-start
│   ├── worker-2-final
│   └── ...
└── summary.md                 # Manager aggregates here when all done
```

Two touch files per worker (see Pitfall 22 in pitfalls.md):
- **`worker-N-start`**: touched within 30s of starting — proves the pane is alive and received the task. Without it, Manager assumes the worker never started.
- **`worker-N-final`**: touched after writing the result — signals "I finished, read my output".

**Why files, not tmux send-keys:** Manager is an LLM, not a deterministic controller. Telling it "use send-keys to dispatch tasks" makes the LLM responsible for tmux syntax, pane indexing, and race conditions. Files are simple, idempotent, inspectable, and survive Manager restarts. They also let the user inspect the system state at any time via `ls ~/blocks-shared/<session>/`.

### What Each Worker Knows (delivered as first message after $AGENT_CMD starts)

```
You are worker-N in blocks session <SESSION>.

Your sub-task: read ~/blocks-shared/<SESSION>/tasks/worker-N.md

Protocol (REQUIRED — protects against tmux server crash, see Pitfall 18):
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

### What the Manager Knows (this is YOU, the current agent session)

When the user invokes `blocks --manager` or "分配 N 个员工", the recipe spawns N workers in tmux and outputs an activation message. **You (this agent) become the Manager.** From this point on, every user message in this chat is a task or follow-up for the Manager role.

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

Timeout: **6-minute rounds** (hard upper bound 7 min) per worker. Longer windows (10+ min) risk the macOS
server crashing mid-round, killing all workers with no recovery — see
references/tmux-server-recovery.md and Pitfall 18. If `done/worker-N-start`
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

When the user sees this, they know Manager mode is active. They reply with a task, you (this agent) follow the protocol.

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

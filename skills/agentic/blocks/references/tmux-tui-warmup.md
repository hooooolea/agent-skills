# tmux TUI Warm-up & send-keys Discipline

The `sleep 6` after `send-keys "$AGENT_CMD"` in `recipes.md` is **load-bearing** — it gates the entire manager-worker protocol. This file documents why, what the failure mode looks like if you skip it, and how to tune it per agent.

## Why 6 seconds

When `send-keys "hermes" Enter` lands in a fresh tmux pane, the agent process starts but **the prompt_toolkit input box is not yet rendered**. Until it renders:

- Subsequent `send-keys` characters fall into the bare shell → may execute as commands
- Characters may mix with the agent's startup banner → role prompt arrives broken
- Characters may be silently dropped by prompt_toolkit's input buffer

`6s` is the **empirically measured** upper bound for hermes (Python + prompt_toolkit). Other agents differ. See [Per-agent warm-up times](#per-agent-warm-up-times) below.

**Why "no warm-up" is broken, in detail:**

| Sleep | Failure rate | What goes wrong |
|-------|--------------|-----------------|
| 0s    | ~80% | Characters land in bare shell; `$SHARED/...` paths in role prompt get executed as `touch` BEFORE the agent even reads the task file → `done-start` is touched by shell, agent has no idea the task exists |
| 1s    | ~30% | prompt_toolkit splash/loading state; some chars lost, some queued |
| 3s    | ~5%  | Most of the time OK; hermes occasionally slow on cold cache |
| 6s    | ~0%  | Verified stable across many rounds |

## Per-agent warm-up times

| Agent | Render tech | Measured warm-up | Safe `sleep` | Source |
|-------|-------------|------------------|--------------|--------|
| **hermes** (default) | Python + prompt_toolkit | 5-7s | 6s | blocks-tested |
| **claude code** | Node + Ink TUI | TBD (~2-4s est.) | 3-4s | TBD empirically |
| **codex** | Rust + Ratatui + Crossterm | **66ms median** | 0.5-1s | PR #23176, 2026-05 |
| **aider** | prompt-toolkit REPL | ~instant | 1s | docs note "banner appears in <100ms" |

**Tuning pattern** — adjust the `sleep` per agent, never below the measured warm-up:

```bash
# recipes.md — replace `sleep 6` with:
case "$AGENT_CMD" in
  hermes)  sleep 6 ;;
  codex)   sleep 1 ;;
  claude)  sleep 4 ;;
  aider)   sleep 1 ;;
  *)       sleep 6 ;;   # safe default
esac
```

## send-keys length limits

`tmux send-keys` does **not** reliably deliver long text in one shot. Observed failure modes (blocks session 2026-06-06, 2x2 worker test):

1. **Prompts > 500 chars** may be truncated or scrambled when sent immediately after `send-keys "hermes" Enter`. The first ~200 chars land in the input box; the rest get buffered and may arrive out of order.
2. **Multi-line prompts** (containing `\` line-continuations) are especially fragile — tmux may insert literal newlines at the wrong place.
3. **Role prompts that contain `$()` or heredoc markers** can confuse the LLM when it later reads the task file (worker may treat them as instructions to analyze, not execute).

**Workarounds (in order of preference):**

1. **Write the task to a file first**, have the worker read it:
   ```bash
   # In the task file
   cat > "$SHARED/tasks/worker-N.md" <<'TASK_EOF'
   Your sub-task: <one-paragraph plain instruction>
   No shell escapes needed.
   TASK_EOF

   # Send-keys a SHORT pointer
   tmux send-keys -t "$SESSION":1.$p "Read $SHARED/tasks/worker-N.md, then touch $SHARED/done/worker-N-start" Enter
   ```
2. **Send the role prompt as a single-line chat message** (≤ 400 chars). Works reliably.
3. **Use multiple send-keys in sequence** with `; sleep 0.2;` between them, building up the prompt char-by-char (last resort; ugly).

## When a worker stalls (timeout decision tree)

If a worker has `done-start` but no `done-final` past 5-6 min, choose between **nudge** and **fallback**:

```
Worker has done-start but no done-final past 5 min
   │
   ├── Pane capture shows worker still working (active spinner, recent token use)
   │     → WAIT. Polling cadence: T+45s, T+2min, T+3min, T+4min, T+5min.
   │       Past 6 min: hard timeout.
   │
   ├── Pane capture shows worker idle (empty prompt `❯`, no spinner)
   │     → NUDGE: send a short chat message via send-keys
   │         "TIME'S UP. Write your final result to $SHARED/results/worker-N.md NOW, then touch $SHARED/done/worker-N-final. You have 60s."
   │       If nudge works → done.
   │       If nudge ignored past 1 more min → FALLBACK.
   │
   └── Pane capture shows worker stuck (looping, error spam, "mulling" forever)
         → FALLBACK directly.
```

**Nudge vs fallback trade-off:**

- **Nudge** (let the worker finish): preserves the worker's reasoning context; faster if worker is just slow.
- **Fallback** (Manager takes over): cleaner result; loses worker's in-context reasoning; higher token cost to redo from scratch.

In the 2026-06-06 blocks test, W3 (screenshot worker) needed a nudge after 10 min; nudge worked, worker wrote a clean result within 90s.

## Manager fallback protocol (when nudge fails)

If nudge doesn't work and worker is genuinely stuck:

1. Read the worker's task file to understand what was being done
2. Re-execute the work in the Manager's own terminal (or delegate_task to a subagent)
3. Write the result to `$SHARED/results/worker-N.md`
4. `touch $SHARED/done/worker-N-final`
5. Add a header to the result:
   ```markdown
   # Worker N result (Manager fallback)

   Worker-N stalled after XmYs. Re-executed by Manager at <timestamp>.

   <original task content>

   ## Result
   <result>
   ```
6. Kill the stalled pane: `tmux send-keys -t "$SESSION":1.$N "/exit" Enter; sleep 2; tmux kill-pane -t "$SESSION":1.$N`
7. Continue polling other workers as normal

The audit trail is honest about the fallback — never silently overwrite a worker's result with your own.

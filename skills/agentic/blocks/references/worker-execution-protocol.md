# Worker Execution Protocol

The full happy-path protocol for a `blocks --manager` worker pane. The role prompt you receive is intentionally short (3-4 lines). This is the long form.

## TL;DR

1. `touch done/worker-N-start` **immediately** (atomic liveness signal)
2. Wait briefly for `tasks/worker-N.md` — the manager may still be writing it
3. Read the task file, do the work, append to `results/worker-N.md`
4. `touch done/worker-N-final`

## Step 1: Liveness Touch (CRITICAL — Do This First)

```bash
touch ~/blocks-shared/<SESSION>/done/worker-N-start
```

Why this is step 1 and not step 2: if the tmux server crashes mid-round, the manager has no other signal that your pane was alive. Without `done/worker-N-start`, the manager assumes you never received the task and times you out. With it, the manager can recover partial results from `results/worker-N.md` even after a crash. See Pitfall 18 (10-min tmux reap) and Pitfall 19 (touch ordering).

**30-second deadline.** If you can't read the task file within 30s of starting, you should at least have touched `start` to prove the pane is alive.

## Step 2: Wait for Task File (May Not Exist Yet)

The role prompt tells you to "read tasks/worker-N.md" — but **that file may not exist yet** when your prompt lands. The manager writes `task.md` and `plan.md` first, then per-worker task files. A typical gap is 10-60 seconds.

```bash
# Touch start FIRST (Step 1).
# Then poll tasks/ for up to 60s before assuming BLOCKED.
for i in 1 2 3 4 5 6; do
  if [ -f ~/blocks-shared/<SESSION>/tasks/worker-N.md ]; then
    break
  fi
  sleep 10
done
```

If the file still doesn't exist after 60s, write a BLOCKED result and stop:

```bash
# In results/worker-N.md
# Status: BLOCKED — task file did not appear within 60s
# Manager may be still writing plan.md; check plan.md and task.md manually.
# Then: touch done/worker-N-final
```

Do NOT invent a task. Do NOT proceed from the plan.md alone unless your role prompt explicitly told you to (it usually doesn't). BLOCKED is a valid outcome — the manager can re-dispatch.

## Step 3: Read and Execute

Read the task file. Follow the spec. Do only what it says. Do not write to other workers' files.

If the task references tools/credentials (e.g. `agent-reach`, `gh`, `tmux`), load the relevant skill with `skill_view(name=...)` first.

**Time budget**: 6-minute rounds (hard upper bound 7). The macOS tmux server can crash around the 10-11 min mark — see Pitfall 18. If you can't finish in 6 min, write what you have to `results/worker-N.md` and touch `done/worker-N-final` with a `Status: PARTIAL` header. Partial is better than stalled.

## Step 4: Write Result

Append a clear markdown result to `results/worker-N.md`. Suggested shape:

```markdown
# Worker N Result

## Status
DONE | PARTIAL | BLOCKED

## Deliverables
- /path/to/asset1.png (description, size, success/fail)
- /path/to/asset2.txt (description)

## Notes
- Any search/command output the manager or downstream workers need
- Any blockers, degradations, or fallbacks used

## Protocol
- [x] done/worker-N-start touched
- [x] result written
- [ ] done/worker-N-final touched (next step)
```

**Order matters**: write the result FIRST, then touch `done/worker-N-final`. If you crash between writing the result and touching the final, the manager can still read your partial output. (Contrast with start: touch FIRST because the manager needs liveness, not output, to know you received the task.)

## Step 5: Final Touch

```bash
touch ~/blocks-shared/<SESSION>/done/worker-N-final
```

That's the only signal the manager waits for. Once this file exists, the manager will read your result and aggregate.

## Status Taxonomy

| Status | When to use | Manager action |
|--------|-------------|----------------|
| `DONE` | All deliverables produced, all listed tasks completed | Read result, incorporate into summary |
| `PARTIAL` | Time ran out, some deliverables missing | Decide: re-dispatch or proceed with what you have |
| `BLOCKED` | Could not start (missing tool, missing credentials, task file never appeared) | Re-dispatch with fix, or skip worker |

Always include the status header at the top of `results/worker-N.md` so the manager can grep it without reading the whole file.

## Pre-Flight Checks (Recommended)

Before heavy work, verify the environment is sane:

- **Network/proxy**: `curl -sI https://api.github.com -m 5` to confirm reachability. Some commands need the 7890 proxy prefix; some (like NASA Worldview) work direct.
- **Tool availability**: `which <tool>` for anything the task calls out.
- **venv activation**: agent-reach tools require `source ~/.agent-reach-venv/bin/activate && <cmd>`.
- **Output directories exist**: `mkdir -p` any path the task writes to. `assets/` and `results/` are usually created by the manager, but be defensive.

If a pre-flight check fails, log it in the result file under a "Pre-flight" header and either fix it (preferred) or mark BLOCKED with the missing dependency named.

## Common Worker Mistakes

| Mistake | Why it fails | Fix |
|---------|--------------|-----|
| Reading the task file before touching start | Crash before step 4 → manager can't tell if you ever started | Touch start FIRST (Step 1) |
| Writing result, then touching final | If crash between, no `done/` file → manager polls forever | Touch start first; touch final last (after result) |
| Inventing work when task file is missing | Manager loses trust, downstream workers consume fake results | BLOCKED with reason, then re-poll once more |
| Writing to other workers' files | Cross-contamination, lost coordination | Stay in your lane: `tasks/worker-N.md` → `results/worker-N.md` → `done/worker-N-*` |
| Holding the result hostage ("I'll touch final after the user replies") | Manager can't aggregate, round times out | Write result, touch final, then ask questions |
| Going past 7 min | tmux server reaps, all workers die | Write PARTIAL, touch final, exit |

## Escalation

If you need help from the manager (e.g. conflicting instructions, missing data, ambiguity in the task):

1. Write the question to `results/worker-N.md` under a `## Question` header.
2. Touch `done/worker-N-final` with `Status: BLOCKED`.
3. Stop.

The manager polls every ~60s and will see your question on the next pass. Do NOT use `tmux send-keys` to message the manager pane — that's not how blocks coordination works.

## See Also

- `references/manager-flow.md` — Manager side protocol (what the manager sees about you)
- `references/pitfalls.md` — Pitfalls 18-22 specifically cover worker timing and crash recovery
- `references/tmux-ops.md` — tmux pane operations, recovery after server crash

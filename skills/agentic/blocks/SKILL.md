---
name: blocks
description: "Use when the user says 'blocks', '分块', '分屏', '2x2', '四宫格', '起N个worker', '分配N个员工', 'manager+workers', or types /blocks. Triggers: 'blocks N', 'blocks 2x2', 'blocks --manager [--workers N]', '分配 N 个员工', '起 N 个 worker'. /blocks slash command (inside a Hermes session) is equivalent. Spawns N parallel Hermes CLIs in one tmux window. N must be even (2/4/6/8). Two modes: flat (N isolated panes, default 2x2) or manager (current chat = Manager; N worker panes coordinate via files at ~/blocks-shared/<session>/{task,plan,tasks,results,done,summary}.md)."
---

# Blocks

One tmux window, N parallel Hermes agents.

## When to Use

- Multiple visible agents in one screen (write + review + research simultaneously).
- A/B compare prompts or models in parallel.
- Manager + Workers for a multi-step task.

Skip for:
- One-off task → `hermes chat -q "..."`.
- Long autonomous missions → `hermes chat -q` background or `cronjob`.
- Multiple agents editing the same git repo → add `-w` (worktree).

## Modes

| Mode | Trigger | What |
|------|---------|------|
| flat | `blocks 2x2`, `blocks 6` | N isolated Hermes panes, no coordination |
| manager | `blocks --manager`, `分配 N 个员工` | Current chat = Manager; N worker panes coordinate via files |

**Manager is the current chat, not a tmux pane.** User always talks to Manager in main chat; N workers live in tmux so the user can watch.

## Rules

1. **N must be even (2/4/6/8).** Odd → one pane gets stretched. Round up + warn.
2. **Order of operations is load-bearing:**
   ```
   new-session -x W -y H → split into N shells → resize-pane to equal size
   → send-keys 'hermes' → sleep 6 → attach
   ```
3. **Never `select-layout tiled` on 1+N (Manager+Workers) layouts** — it re-computes destructively. Safe (but unnecessary) on pure NxM grids if you've already resize-pane'd.
4. **`send-keys` race**: prompt_toolkit needs ~6s. Always `sleep 6` after `send-keys 'hermes'` and before sending the role prompt.
5. **Cap single-round work at 6 minutes** (hard 7). Detached macOS tmux servers can be reaped at 10+ min. See `references/tmux-ops.md` § Recovery.

## Manager Protocol

When you (this Hermes) become the Manager after `blocks --manager`:

1. Save the user's task verbatim to `$SHARED/task.md`.
2. Write your plan to `$SHARED/plan.md`.
3. Break into N sub-tasks, write each to `$SHARED/tasks/worker-i.md`.
4. Poll `$SHARED/done/` every ~60s. `worker-N-start` = alive; `worker-N-final` = finished.
5. Read `results/worker-*.md`, aggregate to `$SHARED/summary.md`, paste in chat.

Worker role prompt (sent after `hermes` starts):

```
You are worker-N in blocks session <SESSION>.
Read ~/blocks-shared/<SESSION>/tasks/worker-N.md.

Protocol:
  1. Within 30s: touch ~/blocks-shared/<SESSION>/done/worker-N-start  (liveness signal)
  2. Read task file, do the work, append to results/worker-N.md
  3. Final step: touch ~/blocks-shared/<SESSION>/done/worker-N-final

Touch START before writing the result. If tmux dies mid-write, the start file
is the only signal that you received the task.
```

Full worker playbook (pre-flight, DONE/PARTIAL/BLOCKED, multi-round, edge cases) → `references/manager-flow.md`.

## Customisation

- **Per-pane profile**: `hermes -p <name>` for total skills/memory/sessions isolation.
- **Per-pane startup prompt**: after the 6s warm-up, `tmux send-keys -t <session>:1.$i 'task' Enter`.
- **Multi-repo edits**: add `-w` → each pane gets its own git worktree, no index lock.
- **Auto-open terminal (macOS)**: writes `/tmp/blocks-attach-<session>.command`, `open`s it. Disable with `DISABLE_BLOCKS_AUTOOPEN=1`. See `references/tmux-ops.md` § Auto-open.

## References

| Topic | File |
|-------|------|
| 5 bash recipes (2x2 / 6 / 2 / manager / list-attach-kill) | `references/recipes.md` |
| All 23 pitfalls with fix snippets | `references/pitfalls.md` |
| Manager + Worker execution protocol (full) | `references/manager-flow.md` |
| tmux split direction + recovery + dynamic pane ops + auto-open | `references/tmux-ops.md` |
| `recovery-scan.sh` — salvage work after tmux server death | `scripts/recovery-scan.sh` |
| Recommended `tmux.conf` snippet (`set -g mouse on` etc.) | `templates/tmux.conf.blocks` |

## Verification

- [ ] `tmux list-panes -t <session>` shows N panes (N even)
- [ ] All panes within 1 cell of each other (`pane_width`/`pane_height`)
- [ ] Each pane shows a Hermes prompt (not blank shell, not "command not found")
- [ ] Typing into a pane is accepted by the Hermes prompt
- [ ] `prefix + d` detaches; reattach with `tmux attach -t <session>` or `blocks attach`

---
name: blocks
description: "Use when the user says 'blocks', '分块', '分屏', '2x2', '四宫格', '起N个worker', '分配N个员工', 'manager+workers'. Triggers: 'blocks 2x2', 'blocks 6', 'blocks --manager [--workers N]', '分配 N 个员工', '起 N 个 worker'. Spawns N parallel AI agent CLIs in one tmux window. N must be even (2/4/6/8). Two modes: flat (N isolated panes, default 2x2) or manager (current chat = Manager; N worker panes coordinate via files at ~/blocks-shared/<session>/{task,plan,tasks,results,done,summary}.md). AGENT_CMD must be set explicitly — blocks is agent-agnostic (hermes / claude / codex / aider). For per-agent CLI adaptation, see references/agent-compatibility.md."
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read
license: MIT
compatibility: "Designed for hermes (default). Adaptable to claude code, codex, aider — see references/agent-compatibility.md. Requires tmux 3.0+ and bash 4+."
metadata:
  version: 1.10.0
  author: ejuer
  hermes:
    tags: [tmux, multi-agent, orchestration, blocks, workers]
---

# Blocks

One tmux window, N parallel AI agents.

## When to Use

- Multiple visible agents in one screen (write + review + research simultaneously).
- A/B compare prompts or models in parallel.
- Manager + Workers for a multi-step task.

Skip for:
- One-off task → `"$AGENT_CMD" -q "..."` (or `--print` for non-interactive).
- Long autonomous missions → `"$AGENT_CMD" chat -q` background or `cronjob` (hermes-only; other agents: use the agent-native equivalent).
- Multiple agents editing the same git repo → add `-w` (worktree).

## Quickstart

**Prerequisite**: pick your agent CLI before spawning. `AGENT_CMD` has no default — blocks is agent-agnostic, so you must set it explicitly:

```bash
AGENT_CMD=hermes bash <spawn-script>.sh   # Hermes
AGENT_CMD=claude bash <spawn-script>.sh   # Claude Code
AGENT_CMD=codex  bash <spawn-script>.sh   # Codex
AGENT_CMD=aider  bash <spawn-script>.sh   # Aider
```

If `AGENT_CMD` is unset, the spawn script errors out with a helpful message instead of silently sending empty Enter to all N panes (which is what would fail with `zsh: command not found: ...`). See `references/pitfalls.md` for the full symptom.

From zero to N parallel agent panes in 3 steps:

1. **Install** (any agent that supports the SKILL.md open standard):
   ```bash
   npx skills add hooooolea/agent-skills
   ```
   Or copy `skills/agentic/blocks/` to `~/.{agent}/skills/blocks/` manually. Herme: `~/.hermes/skills/blocks/`, Claude Code: `~/.claude/skills/blocks/`, Codex: `~/.codex/skills/blocks/`, Aider: per-repo `.aider/skills/blocks/`.

2. **Spawn a flat grid** (N isolated panes, no coordination — each pane is its own agent session):
   ```bash
   blocks 2x2
   ```
   N must be even (2/4/6/8). 4 panes by default.

3. **Spawn Manager + Workers** (current chat = Manager; N workers coordinate via files at `~/blocks-shared/<session>/{task,plan,tasks,results,done,summary}.md`):
   ```bash
   blocks --manager --workers 3
   ```
   Then in this chat: write a task, watch the 3 workers run in tmux, paste `summary.md` when done. See [Manager Protocol](#manager-protocol) for the file-based coordination protocol.

## Modes

| Mode | Trigger | What |
|------|---------|------|
| flat | `blocks 2x2`, `blocks 6` | N isolated agent panes, no coordination |
| manager | `blocks --manager`, `分配 N 个员工` | Current chat = Manager; N worker panes coordinate via files |

**Manager is the current chat, not a tmux pane.** User always talks to Manager in main chat; N workers live in tmux so the user can watch.

## Rules

1. **N must be even (2/4/6/8).** Odd → one pane gets stretched. Round up + warn.
2. **Order of operations is load-bearing:**
   ```
   new-session -x W -y H → split into N shells → resize-pane to equal size
   → send-keys "$AGENT_CMD" → sleep 6 → attach
   ```
3. **`select-layout tiled` on pure NxM grids: call it BEFORE `resize-pane`, not after.** On macOS tmux 3.x, `resize-pane` alone is unreliable (one pane collapses to 1 row). Always: splits → `select-layout tiled` → `resize-pane`. See `references/tmux-grid-bug.md`. **Never use `tiled` on 1+N (Manager+Workers) layouts** — it re-computes destructively.
4. **`send-keys` race**: prompt_toolkit needs ~6s. Always `sleep 6` after `send-keys "$AGENT_CMD"` and before sending the role prompt.
5. **Cap single-round work at 6 minutes** (hard 7). Detached macOS tmux servers can be reaped at 10+ min. See `references/tmux-ops.md` § Recovery.

## Manager Protocol

When you (this agent) become the Manager after `blocks --manager`:

1. Save the user's task verbatim to `$SHARED/task.md`.
2. Write your plan to `$SHARED/plan.md`.
3. Break into N sub-tasks, write each to `$SHARED/tasks/worker-i.md`.
4. Poll `$SHARED/done/` every ~60s. `worker-N-start` = alive; `worker-N-final` = finished.
5. Read `results/worker-*.md`, aggregate to `$SHARED/summary.md`, paste in chat.

Worker role prompt (sent after `$AGENT_CMD` starts):

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

- **Per-pane profile**: `"$AGENT_CMD" -p <name>` for total skills/memory/sessions isolation (hermes profile flag; see `references/agent-compatibility.md` for claude / codex / aider equivalents).
- **Per-pane startup prompt**: after the 6s warm-up, `tmux send-keys -t <session>:1.$i 'task' Enter`.
- **Multi-repo edits**: add `-w` → each pane gets its own git worktree, no index lock (hermes + claude code only; see `references/agent-compatibility.md`).
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

## Examples

Three real use cases — flat grid for A/B, manager for parallel research, file protocol for the orchestration itself.

### 1. A/B compare 4 models on one prompt (flat 2x2)

You wrote a tricky prompt. One model isn't enough signal — you want 4 opinions in parallel without 4 separate chat sessions.

1. `blocks 2x2 --label regex-test` — spawns 4 isolated panes, **no coordination**, each is its own agent session
2. Each pane gets the same prompt but a different `--model` (set via `~/.hermes/config.yaml` profiles, or per-pane startup prompt)
3. Watch all 4 in tmux, screenshot the best answer, kill the rest with `blocks kill regex-test`

vs. 4 separate chat sessions: ~4× the wall-clock, ~4× the context-switching tax.

### 2. Research 4 LLM API prices in parallel (manager + 4 workers)

Goal: get pricing for OpenAI / Anthropic / Google / Mistral APIs and ship a comparison table.

1. In this chat (Manager): `blocks --manager --workers 4`
2. Write the task: "Each worker researches 1 of: openai/anthropic/google/mistral. Save to `results/worker-N.md`. Include input/output $ per 1M tokens, context window, batch discount, free tier."
3. 4 tmux panes appear. Each reads `task.md`, touches `done/worker-N-start` (liveness), does the work, writes `results/worker-N.md`, touches `done/worker-N-final`
4. After ~3 min all 4 `done/worker-N-final` files exist. Manager sees "4/4 finished", reads all 4 results, writes `summary.md`
5. You paste `summary.md` → comparison table

vs. sequential: ~12 min. With blocks: ~3 min wall clock + ~30s orchestration overhead.

### 3. The 5-step file protocol (what Manager + Workers actually do)

| Step | Who | Action | File touched |
|------|-----|--------|--------------|
| 1 | Manager (this chat) | Write the task | `task.md` |
| 2 | Workers (N tmux panes) | Each reads `task.md`, touches liveness signal | `done/worker-N-start` |
| 3 | Workers | Do the work, append findings | `results/worker-N.md` |
| 4 | Workers | Touch final signal | `done/worker-N-final` |
| 5 | Manager | Collect N results, write synthesis | `summary.md` |

All paths under `~/blocks-shared/<session>/`. Workers can't see each other (no IPC) — coordination is **purely file-based**, which is what makes the protocol robust to tmux/agent crashes (`scripts/recovery-scan.sh` salvages whatever's already in `results/`).

Full protocol with edge cases (DONE/PARTIAL/BLOCKED, multi-round, agent crash mid-write, late results) → `references/manager-flow.md`.

## Verification

- [ ] `tmux list-panes -t <session>` shows N panes (N even)
- [ ] All panes within 1 cell of each other (`pane_width`/`pane_height`)
- [ ] Each pane shows an agent prompt (not blank shell, not "command not found")
- [ ] Typing into a pane is accepted by the agent prompt
- [ ] `prefix + d` detaches; reattach with `tmux attach -t <session>` or `blocks attach`

---
layout: default
---

<!-- Source of truth: this file is a digest of README.md (Skills + install sections only). Edit README.md and re-sync this file. -->

# Agent Skills

## Skills

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — Run N parallel AI agents in one tmux window (Manager + Workers coordinate multi-step tasks, any N ≥ 1).
  ![Blocks running: a 2x2 grid of 4 panes with Manager + worker-1..4 coordination](assets/blocks-running.png)
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — Multi-sub-agent development flow (5 phases: decompose → explore → code → review → ship).
  ![dev-task: 5-phase flow — decompose → explore → code → review → ship](assets/dev-task.svg)
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — Save session state at the end so the next session can pick up where you left off.
  ![session-summary: structured .session_summary.md template](assets/session-summary.svg)

## Install

Copy the skills you want into your agent's skills directory, then restart:

- **Hermes** — `~/.hermes/skills/<name>/`
- **Claude Code** — `~/.claude/skills/<name>/`
- **Codex** — `~/.codex/skills/<name>/`
- **Aider** — per-repo `.aider/skills/<name>/`

Install all three (change `DEST` for your agent):

```bash
# All agents use flat <name>/SKILL.md layout. Set DEST for your agent:
DEST=~/.hermes/skills        # Hermes
# DEST=~/.claude/skills      # Claude Code
# DEST=~/.codex/skills       # Codex
# DEST=.aider/skills         # Aider (per-repo — run inside your project)

cp -r skills/agentic/blocks             "$DEST"/
cp -r skills/productivity/dev-task       "$DEST"/
cp -r skills/productivity/session-summary "$DEST"/
```

Cross-agent differences (profile flag, worktree, slash-command registration) → [`skills/agentic/blocks/references/agent-compatibility.md`](skills/agentic/blocks/references/agent-compatibility.md).

After spawning blocks, enter the tmux window and press `Ctrl-b` then `?` for all keybindings.

---

## 技能

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — 一个 tmux 窗口跑 N 个并行 AI agent（Manager + Workers 协调多步任务，任意 N ≥ 1）
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — 多子代理开发流（5 阶段：拆任务 → 探索 → 编码 → 审查 → 收尾）
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — session 结束前存个档，下次接着干

## 安装

把想要的 skill 复制到 agent skills 目录，重启 agent。全装命令见上方英文区（改 `DEST` 变量即可）。

跨 agent 差异见 [`skills/agentic/blocks/references/agent-compatibility.md`](skills/agentic/blocks/references/agent-compatibility.md)。

blocks 跑起来后进 tmux 窗口，按 `Ctrl-b` 然后 `?` 列出所有快捷键。

---

MIT — see [LICENSE](LICENSE)

---
layout: default
---

<!-- Source of truth: this file is a digest of README.md (Skills + install sections only). Edit README.md and re-sync this file. -->

# Agent Skills

## Skills

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — 一个 tmux 窗口跑 N 个并行 AI agent（Manager + Workers 协调多步任务）
  ![blocks: a 2x2 grid of 4 panes with Manager + workers coordination](assets/blocks-running.png)
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — 多子代理开发流（5 阶段：拆任务 → 探索 → 编码 → 审查 → 收尾）
  ![dev-task: 5-phase horizontal flow with Phase 3 review gate](assets/dev-task.svg)
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — session 结束前存个档，下次接着干
  ![session-summary: 6-section .session_summary.md template](assets/session-summary.svg)

## 安装

把想要的 skill 复制到你的 agent skills 目录，重启 agent：

- **Hermes** — `~/.hermes/skills/<name>/`
- **Claude Code** — `~/.claude/skills/<name>/`
- **Codex** — `~/.codex/skills/<name>/`
- **Aider** — per-repo `.aider/skills/<name>/`

全装（按你的 agent 替换路径）：

```bash
# Hermes
cp -r skills/* ~/.hermes/skills/

# Claude Code (requires <category>/<name>/ subdir)
cp -r skills/agentic/blocks ~/.claude/skills/blocks
cp -r skills/productivity/dev-task ~/.claude/skills/dev-task
cp -r skills/productivity/session-summary ~/.claude/skills/session-summary

# Codex / Aider: see skills/agentic/blocks/references/agent-compatibility.md
```

跨 agent 差异（profile flag、worktree、slash-command 注册路径）见 [`skills/agentic/blocks/references/agent-compatibility.md`](skills/agentic/blocks/references/agent-compatibility.md)。

blocks 跑起来后进 tmux 窗口，按 `Ctrl-b` 然后 `?` 列出所有快捷键。

---

MIT

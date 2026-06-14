---
layout: default
---

<!-- Source of truth: this file is a digest of README.md (Skills + install sections only). Edit README.md and re-sync this file. -->

# Agent Skills

## Skills

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — 一个 tmux 窗口跑 N 个并行 AI agent（Manager + Workers 协调多步任务）
  ![Blocks running: a 2x2 grid of 4 panes with Manager + worker-1..4 coordination](assets/blocks-running.png)
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — 多子代理开发流（5 阶段：拆任务 → 探索 → 编码 → 审查 → 收尾）
  ![dev-task: 5-phase flow — decompose → explore → code → review → ship](assets/dev-task.svg)
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — session 结束前存个档，下次接着干
  ![session-summary: structured .session_summary.md template](assets/session-summary.svg)

## 安装

把想要的 skill 复制到你的 agent skills 目录，重启 agent：

- **Hermes** — `~/.hermes/skills/<name>/`
- **Claude Code** — `~/.claude/skills/<name>/`
- **Codex** — `~/.codex/skills/<name>/`
- **Aider** — per-repo `.aider/skills/<name>/`

全装（按你的 agent 替换路径）：

```bash
# 所有 agent 都用扁平 <name>/SKILL.md 布局。按你的 agent 修改 DEST：
DEST=~/.hermes/skills        # Hermes
# DEST=~/.claude/skills      # Claude Code
# DEST=~/.codex/skills       # Codex
# DEST=.aider/skills         # Aider（per-repo — 在项目目录里跑）

cp -r skills/agentic/blocks             "$DEST"/
cp -r skills/productivity/dev-task       "$DEST"/
cp -r skills/productivity/session-summary "$DEST"/
```

跨 agent 差异（profile flag、worktree、slash-command 注册路径）见 [`skills/agentic/blocks/references/agent-compatibility.md`](skills/agentic/blocks/references/agent-compatibility.md)。

blocks 跑起来后进 tmux 窗口，按 `Ctrl-b` 然后 `?` 列出所有快捷键。

---

MIT — 见 [LICENSE](LICENSE)

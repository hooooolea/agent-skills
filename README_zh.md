[English](README.md) | 中文

# Agent Skills

## Skills

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — 一个 tmux 窗口跑 N 个并行 AI agent
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — session 结束前存个档，下次接着干
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — 多子代理开发流

## 安装

把想要的 skill 复制到你的 agent skills 目录（hermes: `~/.hermes/skills/<name>/`, claude code: `~/.claude/skills/<name>/`, codex: `~/.codex/skills/<name>/`），重启 agent。

全装：

```bash
# Hermes:
cp -r skills/* ~/.hermes/skills/
# Claude Code:
cp -r skills/agentic/blocks ~/.claude/skills/blocks
cp -r skills/agentivity/dev-task ~/.claude/skills/dev-task
cp -r skills/productivity/session-summary ~/.claude/skills/session-summary
# Codex / Aider: 见 references/agent-compatibility.md
```

blocks 跑起来后进 tmux 窗口，按 `Ctrl-b` 然后 `?` 列出所有快捷键。

---

MIT

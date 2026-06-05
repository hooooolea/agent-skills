English | [中文](README_zh.md)

# Agent Skills

## Skills

- **blocks** — [SKILL.md](skills/agentic/blocks/SKILL.md) — 一个 tmux 窗口跑 N 个并行 Hermes
- **session-summary** — [SKILL.md](skills/productivity/session-summary/SKILL.md) — session 结束前存个档，下次接着干
- **dev-task** — [SKILL.md](skills/productivity/dev-task/SKILL.md) — 多子代理开发流

## 安装

把想要的 `SKILL.md` 复制到 `~/.hermes/skills/<name>/`，重启 agent。

全装：

```bash
cp -r skills/* ~/.hermes/skills/
```

blocks 跑起来后进 tmux 窗口，按 `Ctrl-b` 然后 `?` 列出所有快捷键。

---

MIT

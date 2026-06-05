[English](README.md) | 中文

# Agent Skills

三个 Hermes Agent 的 skill。每个就是一个 SKILL.md。

## Skills

- **blocks** — 一个 tmux 窗口跑 N 个并行 Hermes。spawn 后自动弹 Terminal.app attach，鼠标点 / `Ctrl-b` 方向键 切 worker pane 实时看进度。detach 用 `Ctrl-b d`，workers 后台继续。
- **session-summary** — session 结束前存个档，下次接着干
- **dev-task** — 多子代理开发流

## 安装

把想要的 `SKILL.md` 复制到 `~/.hermes/skills/<name>/`，重启 agent。

全装：

```bash
cp -r skills/* ~/.hermes/skills/
```

---

MIT

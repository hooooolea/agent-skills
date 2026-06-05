English | [中文](README_zh.md)

# Agent Skills

三个 Hermes Agent 的 skill。每个就是一个 SKILL.md。

## Skills

- **blocks** — 一个 tmux 窗口跑 N 个并行 Hermes。spawn 后会自动弹一个 Terminal.app attach 上去，鼠标点 / `Ctrl-b` 方向键 切 worker pane 实时看每个 worker 干活。detach 按 `Ctrl-b d`，workers 后台继续。
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

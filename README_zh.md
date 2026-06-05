[English](README.md) | 中文

<div align="center">

# Agent Skills

_Hermes Agent 的 SKILL.md 集合 — 直接用的并行 Agent 编排、多子代理开发流、session 存档。_

![Built for Hermes · MIT](https://img.shields.io/badge/Hermes-Agent-blue)

</div>

---

## 这里有什么

每个 skill 都在 `skills/<分类>/<skill 名>/` 一个 `SKILL.md` 文件。扔到 `~/.hermes/skills/<名>/`（或你 agent 对应的目录）就能用。不用 npm install，不用 Python venv，不用 API key —— 就是 markdown，教你的 agent 什么时候用、怎么用好。

| Skill | 分类 | 一句话 |
|-------|------|--------|
| **[blocks](./skills/agentic/blocks/SKILL.md)** | agentic | 一个 tmux 窗口起 N 个并行 Hermes agent — flat（独立）或 manager（协调） |
| **[session-summary](./skills/productivity/session-summary/SKILL.md)** | productivity | 任何 session 结束前存档到 `.session_summary.md`；下次打开秒速续上 |
| **[dev-task](./skills/productivity/dev-task/SKILL.md)** | productivity | 5 阶段多子代理开发流（拆 → 探 → 写 → 审 → 收） |

按分类浏览：[`agentic/`](./skills/agentic/) · [`productivity/`](./skills/productivity/)

---

## 主推：blocks

仓库的招牌 skill。让你在一个终端窗口里跑 **N 个并行 Hermes agent**：

```bash
# 在任何 Hermes session 里：
/blocks --manager --workers 4
# 或者直接说人话：
"分配 4 个员工"
```

发生了什么：
1. 你当前的对话变成 **Manager**（不开新 tmux pane）。
2. 弹出 4 个 worker pane（tmux 网格），同时 Terminal.app 窗口自动弹出。
3. 你给任务 → Manager 拆 4 个子任务派下去。
4. Workers 并行跑，结果写到 `~/blocks-shared/<session>/results/`，完成时 touch done。
5. Manager 汇总，回主对话汇报。

支持两种模式：
- **Flat** — N 个独立 pane，你驱动每一个
- **Manager** — 1 Manager + N Workers，文件协调，避免重复劳动

[→ 完整文档在 `skills/agentic/blocks/SKILL.md`](./skills/agentic/blocks/SKILL.md)

---

## 安装

```bash
# Hermes Agent
cp skills/agentic/blocks/SKILL.md ~/.hermes/skills/blocks/SKILL.md

# 或者一次性全装
cp -r skills/* ~/.hermes/skills/

# Claude Code / Cursor / OpenClaw — 路径类似，看各自文档
```

重启 agent session，skill 就激活。说 `description:` 字段里任何关键词就会触发。

---

MIT · [github.com/hooooolea/agent-skills](https://github.com/hooooolea/agent-skills)

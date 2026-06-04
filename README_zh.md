[English](README.md) | 中文

<div align="center">

# Session Summary

_给你的 AI Agent 加个存档点。任何会话都能秒速续上。_

![完整测评见 ejuerz.com](assets/blog-preview.png)

</div>

---

## 干什么的

AI Agent 聊得越久越傻。早期的细节忘了，说过的话重复了，思路开始飘。关掉重开？又得从头解释一遍项目。

**Session Summary** 解决这个。一个文件。一个习惯。进度不再丢。

```bash
# 会话结束 — 存档
"总结一下本次会话，写入 .session_summary.md"

# 下次会话 — 读档
"读 .session_summary.md，接着上次继续"
```

## 存了什么

| 栏目 | 内容 |
|------|------|
| 项目概览 | 在做什么、技术栈、关键上下文 |
| 已完成 | 做了什么、具体文件路径、结果 |
| 当前状态 | 做到哪了、卡在哪里 |
| 下一步 | 按优先级排的待办 |
| 已知坑 | 踩过的坑和绕过去的办法 |

每条都写具体——文件路径、行号、哪条命令管用。不写模棱两可的废话。

## 怎么装

把 `SKILL.md` 扔进 Agent 的 skills 目录。搞定。

支持所有兼容 skill 的 Agent——Claude Code、Hermes、Cursor、OpenClaw 都行。

## 为什么要用

| 不用 | 用了 |
|------|------|
| 聊 50 条之后 Agent 开始忘 | 每次都是新会话，文件里装着完整历史 |
| 不敢关 Agent | 随时关，秒速续 |
| 每次重讲项目 | 读一个文件，Agent 全知道 |
| 不记得试过什么 | 完整记录每次尝试、成功和失败 |

---

MIT · [github.com/hooooolea/agent-session-summary](https://github.com/hooooolea/agent-session-summary)

| English | [中文](README_zh.md)

# Agent Skills

[![GitHub stars](https://img.shields.io/github/stars/hooooolea/agent-skills.svg)](https://github.com/hooooolea/agent-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SKILL.md standard](https://img.shields.io/badge/standard-agentskills.io-f59e0b)](https://agentskills.io)

**三个 SKILL.md，跨 Hermes / Claude Code / Codex / Aider。** 任何支持 [SKILL.md 开放标准](https://agentskills.io/specification) 的 agent 都能装。

## Quickstart

Three steps from zero to 3 working skills:

1. **Install** (works for any agent that supports the [SKILL.md open standard](https://agentskills.io/specification)):
   ```bash
   npx skills add hooooolea/agent-skills
   ```
   Or skip `npx` and copy manually — see [手动安装](#手动安装不用-npx-skills) below.

2. **Pick your agent** — `npx skills` auto-detects Claude Code / Codex / Cursor. For Hermes (or any unsupported agent):
   ```bash
   cp -r skills/* ~/.hermes/skills/
   ```

3. **Restart your agent**, then in chat say one of:
   - "用 2x2 跑 4 个 agent 对比 X" → triggers `blocks`
   - "实现 / 开发 / 改代码" → triggers `dev-task`
   - "session 收尾 / 存个档" → triggers `session-summary`

## 为什么

每个 AI agent 都有长尾的"重复工作流"——这些工作流被埋在每次对话里，靠 prompt 临时拼装。SKILL.md 开放标准（Anthropic 2025-12 发布，OpenAI / Cursor 共同采纳）让任何 agent 自动加载 `~/.{agent}/skills/<name>/SKILL.md`，把可复用工作流沉淀成可版本控制的 Markdown。

本仓库是按这个标准写成的 3 个 skill 集合。

![blocks 2x2 — Manager + 4 workers in one tmux window](assets/blocks-2x2.svg)

## Features

- **跨 agent** — 同一份 SKILL.md 在 Hermes / Claude Code / Codex / Aider 都能跑（profile flag / worktree / slash command 的差异见 [compat 表](skills/agentic/blocks/references/agent-compatibility.md)）
- **Open standard** — 严格遵守 [agentskills.io spec](https://agentskills.io/specification)
- **零依赖** — 纯 Markdown + 可选 shell 脚本，无需 npm / pip
- **小 footprint** — 每个 SKILL.md body ≤ 500 行 / ≤ 5000 tokens
- **可发现** — 仓库结构兼容 Vercel `npx skills` CLI / SkillsMP.com auto-index

## Skills

- **[blocks](skills/agentic/blocks/SKILL.md)** — 一个 tmux 窗口跑 N 个并行 AI agent（Manager + Workers 协调跑多步任务）
- **[dev-task](skills/productivity/dev-task/SKILL.md)** — 多子代理开发流（5-phase: 拆任务→探索→编码→审查→收尾）
- **[session-summary](skills/productivity/session-summary/SKILL.md)** — session 结束前存个档，下次接着干

## 手动安装（不用 `npx skills`）

把 SKILL.md 复制到你的 agent 的 skills 目录，重启 agent：

| Agent | 路径 |
|-------|------|
| Hermes | `~/.hermes/skills/<name>/` |
| Claude Code | `~/.claude/skills/<name>/` |
| Codex | `~/.codex/skills/<name>/` |
| Aider | per-repo `.aider/skills/<name>/` |

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

## When NOT to use

- 你要写的是 agent framework / runtime / SDK — 那是 `hermes-agent` / `claude-code` 本体的事，不是 skill 的事
- 工作流是一次性的（不会重复 2 次）— 写 prompt 比写 SKILL.md 快
- 需要 GUI / IDE 集成 — skill 是纯文本约定，没有 UI 规范
- 你已经有成熟的工作流（> 1 年积累） — 那应该 fork 维护成自己的 private repo，而不是从零写

## Contributing

Issues / PRs 都欢迎。改 SKILL.md 前先读 [agentskills.io spec](https://agentskills.io/specification)。跨 agent 兼容性的差异点统一在 [agent-compatibility.md](skills/agentic/blocks/references/agent-compatibility.md) 维护。

每个 PR 触发 CI 跑 [check-skill-spec.py](https://github.com/hooooolea/hermes-agent/blob/main/skills/software-development/hermes-agent-skill-authoring/scripts/check-skill-spec.py)：description ≤ 1024 chars、name 匹配父目录、body ≤ 500 行、无 `or types /<name>` 触发。

## Resources

### Official documentation
- [agentskills.io spec](https://agentskills.io/specification) — the open standard
- [Anthropic skills announcement](https://www.anthropic.com/news/skills) (Oct 2025) — the original writeup

### Community
- [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) — 1000+ skills curated list
- [Vercel `npx skills` CLI](https://github.com/vercel-labs/skills) — cross-agent install (50+ agents)
- [SkillsMP.com](https://skillsmp.com) — auto-index of public GitHub SKILL.md

### Inspiration
- [Anthropic skills repo](https://github.com/anthropics/skills) — example skills
- [Lenny's Newsletter](https://www.lennysnewsletter.com/p/everyone-should-be-using-claude-code) — 50 Claude Code use cases

## Acknowledgments

- [Anthropic](https://www.anthropic.com/) — published the SKILL.md open standard
- [Vercel](https://vercel.com/) — `npx skills` CLI cross-agent install
- [ComposioHQ](https://github.com/ComposioHQ/awesome-claude-skills) — community curation
- [SkillsMP](https://skillsmp.com) — auto-index of public SKILL.md

## Community

没 Discord — 用 GitHub Issues / Discussions 凑合：
- [Issues](https://github.com/hooooolea/agent-skills/issues) — bug / feature request
- [Discussions](https://github.com/hooooolea/agent-skills/discussions) — Q&A / 想法

## Live site

GitHub Pages 镜像：<https://hooooolea.github.io/agent-skills/>

---

MIT

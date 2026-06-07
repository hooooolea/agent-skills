| English | [中文](README_zh.md)

# Agent Skills

[![GitHub stars](https://img.shields.io/github/stars/hooooolea/agent-skills.svg)](https://github.com/hooooolea/agent-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SKILL.md standard](https://img.shields.io/badge/standard-agentskills.io-f59e0b)](https://agentskills.io)

**三个 SKILL.md，跨 Hermes / Claude Code / Codex / Aider。** 任何支持 [SKILL.md 开放标准](https://agentskills.io/specification) 的 agent 都能装。

## Quickstart

Three steps to get all 3 skills running on any agent:

1. **Download the SKILL.md files** — clone the repo (or just download the 3 folders you want):
   ```bash
   # Option A: full repo (lets you read source, file issues, send PRs)
   git clone https://github.com/hooooolea/agent-skills ~/agent-skills

   # Option B: tarball only (no git, smallest)
   curl -fsSL https://github.com/hooooolea/agent-skills/archive/refs/heads/main.tar.gz | tar xz
   ```

2. **Copy into your agent's skills directory**:

   | Agent | Path | Layout |
   |-------|------|--------|
   | Hermes | `~/.hermes/skills/` | flat: `<name>/SKILL.md` |
   | Claude Code | `~/.claude/skills/` | needs `<category>/<name>/` subdir |
   | Codex | `~/.codex/skills/` | flat: `<name>/SKILL.md` |
   | Aider | per-repo `.aider/skills/` | flat: `<name>/SKILL.md` |

   ```bash
   # Hermes / Codex / Aider (flat)
   cp -r ~/agent-skills/skills/* ~/.hermes/skills/    # or ~/.codex/skills/

   # Claude Code (category subdir required)
   cp -r ~/agent-skills/skills/agentic/blocks         ~/.claude/skills/blocks
   cp -r ~/agent-skills/skills/productivity/dev-task  ~/.claude/skills/dev-task
   cp -r ~/agent-skills/skills/productivity/session-summary ~/.claude/skills/session-summary
   ```

3. **Restart your agent**, then in chat say one of:
   - "用 2x2 跑 4 个 agent 对比 X" → triggers `blocks`
   - "实现 / 开发 / 改代码" → triggers `dev-task`
   - "session 收尾 / 存个档" → triggers `session-summary`

> 💡 **Don't want to copy manually?** Vercel's [`npx skills add hooooolea/agent-skills`](https://github.com/vercel-labs/skills) CLI does the clone + cp + agent-detection for you (50+ agents supported). But it's a wrapper, not a requirement — the SKILL.md open standard works without any tooling.

- **Open standard** — 按 [agentskills.io spec](https://agentskills.io/specification) 写, 不绑定任何 vendor
- **零依赖** — 纯 Markdown + 可选 shell 脚本，无需 npm / pip
- **小 footprint** — 每个 SKILL.md body ≤ 500 行 / ≤ 5000 tokens
- **可发现** — 仓库结构兼容 Vercel `npx skills` CLI / SkillsMP.com auto-index

## Skills

- **[blocks](skills/agentic/blocks/SKILL.md)** — 一个 tmux 窗口跑 N 个并行 AI agent（Manager + Workers 协调跑多步任务）
- **[dev-task](skills/productivity/dev-task/SKILL.md)** — 多子代理开发流（5-phase: 拆任务→探索→编码→审查→收尾）
- **[session-summary](skills/productivity/session-summary/SKILL.md)** — session 结束前存个档，下次接着干

## When NOT to use

3 个 skill 各自的边界:

### blocks
- 1 task 1 agent 就够 → `"$AGENT_CMD" -q "..."` 更快
- task < 5 min → Manager + N workers 的 overhead 太大
- 没 parallelizable 子任务 → 不用 N 个 worker 跑

### dev-task
- 改动 < 50 行 (单文件 trivial fix) → 直接改
- 不是 coding task (调研 / 写文档) → ad-hoc prompt 或 session-summary 收尾
- 不在 git repo (没 manifest) → 跑不了 (skill 强依赖 manifest)

### session-summary
- session < 30 min 简单任务 → 不用写, 自然结束
- task 1-2 步就完 → 没东西可总结

## Contributing

Issues / PRs 都欢迎。改 SKILL.md 前先读 [agentskills.io spec](https://agentskills.io/specification)。跨 agent 兼容性的差异点统一在 [agent-compatibility.md](skills/agentic/blocks/references/agent-compatibility.md) 维护。

每个 PR 触发 CI 跑 [check-skill-spec.py](https://github.com/hooooolea/hermes-agent/blob/main/skills/software-development/hermes-agent-skill-authoring/scripts/check-skill-spec.py)：description ≤ 1024 chars、name 匹配父目录、body ≤ 500 行、无 `or types /<name>` 触发。

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

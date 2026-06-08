[English](README.md) | [中文](README_zh.md)

# Agent Skills

[![GitHub stars](https://img.shields.io/github/stars/hooooolea/agent-skills.svg)](https://github.com/hooooolea/agent-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SKILL.md standard](https://img.shields.io/badge/standard-agentskills.io-f59e0b)](https://agentskills.io)

Three SKILL.md files implementing the open [SKILL.md standard](https://agentskills.io/specification). Install on any agent that supports it: Hermes, Claude Code, Codex, Aider.

## Overview

A small, focused library of three skills — `blocks`, `dev-task`, `session-summary` — each written once and installable on any agent that reads `SKILL.md`. No vendor lock-in, no runtime, no dependencies. The repository is the source of truth; everything is plain Markdown plus optional shell scripts.

## Quickstart

Three steps to install all three skills on any agent:

1. **Download the SKILL.md files** — clone the repo (or just download the folders you want):
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
   - `用 2x2 跑 4 个 agent 对比 X` → triggers `blocks`
   - `实现 / 开发 / 改代码` → triggers `dev-task`
   - `session 收尾 / 存个档` → triggers `session-summary`

> 💡 **Don't want to copy manually?** Vercel's [`npx skills add hooooolea/agent-skills`](https://github.com/vercel-labs/skills) CLI handles clone + copy + agent detection for you (50+ agents supported). But it is a wrapper, not a requirement — the SKILL.md open standard works without any tooling.

- **Open standard** — Implements the [agentskills.io spec](https://agentskills.io/specification); not tied to any vendor.
- **Zero dependencies** — Pure Markdown plus optional shell scripts; no npm or pip required.
- **Small footprint** — Each SKILL.md body is at most 500 lines or 5000 tokens.
- **Discoverable** — Repo structure works with Vercel `npx skills` CLI and SkillsMP.com auto-index.

## Skills

- **[blocks](skills/agentic/blocks/SKILL.md)** — Run N parallel AI agents in a single tmux window (Manager + Workers coordinate multi-step tasks).

  | Manager (current chat) | worker-1 (start → work → append) |
  |:---:|:---:|
  | ![](assets/blocks-pane-1.svg) | ![](assets/blocks-pane-2.svg) |
  | **worker-2 (in progress, 30%)** | **worker-3 done / worker-4 running** |
  | ![](assets/blocks-pane-3.svg) | ![](assets/blocks-pane-4.svg) |

- **[dev-task](skills/productivity/dev-task/SKILL.md)** — Multi-sub-agent development flow (5 phases: decompose → explore → code → review → ship).

  ![](assets/dev-task.svg)

- **[session-summary](skills/productivity/session-summary/SKILL.md)** — Save session state at the end so the next one can pick up where you left off.

  ![](assets/session-summary.svg)

## When NOT to use

Per-skill boundaries:

### blocks
- 1 task, 1 agent is enough → `"$AGENT_CMD" -q "..."` is faster.
- Task < 5 min → Manager + N workers overhead is too high.
- No parallelizable sub-tasks → no reason to spin up N workers.

### dev-task
- Change < 50 lines (single-file trivial fix) → just edit directly.
- Not a coding task (research / doc writing) → use ad-hoc prompt or wrap with session-summary.
- Not inside a git repo (no manifest) → cannot run (skill depends on manifest).

### session-summary
- Session < 30 min, trivial task → skip; end naturally.
- Task is 1-2 steps → nothing worth summarising.

## Contributing

Issues and PRs welcome. Before editing a SKILL.md, read the [agentskills.io spec](https://agentskills.io/specification). Cross-agent compatibility differences are tracked centrally in [agent-compatibility.md](skills/agentic/blocks/references/agent-compatibility.md).

Every PR triggers CI to run [check-skill-spec.py](https://github.com/hooooolea/hermes-agent/blob/main/skills/software-development/hermes-agent-skill-authoring/scripts/check-skill-spec.py): description ≤ 1024 chars, name matches parent directory, body ≤ 500 lines, no `or types /<name>` triggers.

## Acknowledgments

- [Anthropic](https://www.anthropic.com/) — published the SKILL.md open standard.
- [Vercel](https://vercel.com/) — `npx skills` CLI for cross-agent install.
- [ComposioHQ](https://github.com/ComposioHQ/awesome-claude-skills) — community skill curation.
- [SkillsMP](https://skillsmp.com) — auto-index of public SKILL.md files.

## Community

No Discord — GitHub Issues / Discussions is the channel:
- [Issues](https://github.com/hooooolea/agent-skills/issues) — bug / feature request.
- [Discussions](https://github.com/hooooolea/agent-skills/discussions) — Q&A / ideas.

## Live site

GitHub Pages mirror: <https://hooooolea.github.io/agent-skills/>

## License

MIT — see [LICENSE](LICENSE).

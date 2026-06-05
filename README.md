English | [中文](README_zh.md)

<div align="center">

# Agent Skills

_A curated collection of Hermes Agent SKILL.md files — drop-in skills for parallel-agent orchestration, multi-subagent dev workflows, and session checkpoints._

![Built for Hermes · MIT licensed](https://img.shields.io/badge/Hermes-Agent-blue)

</div>

---

## What's Here

Each skill lives in `skills/<category>/<skill-name>/` as a single `SKILL.md` file. Drop it into `~/.hermes/skills/<name>/` (or your agent's equivalent) and use it immediately. No npm install, no Python venv, no API keys — just markdown that teaches your agent when to use the skill and how to do it well.

| Skill | Category | One-liner |
|-------|----------|-----------|
| **[blocks](./skills/agentic/blocks/SKILL.md)** | agentic | Spawn N parallel Hermes agents in tmux panes — flat (independent) or manager (coordinated) |
| **[session-summary](./skills/productivity/session-summary/SKILL.md)** | productivity | Checkpoint any agent session into a `.session_summary.md`; next session resumes instantly |
| **[dev-task](./skills/productivity/dev-task/SKILL.md)** | productivity | 5-phase multi-subagent dev workflow (decompose → explore → code → review → ship) |

Browse by category: [`agentic/`](./skills/agentic/) · [`productivity/`](./skills/productivity/)

---

## Featured: blocks

The flagship skill of this repo. Lets you run **N parallel Hermes agents in one terminal window**:

```bash
# Inside any Hermes session:
/blocks --manager --workers 4
# OR natural language:
"分配 4 个员工"
```

What happens:
1. Your current chat becomes the **Manager** (no separate tmux pane).
2. **4 worker panes** spawn in a tmux grid and a Terminal window pops open.
3. You say a task → the Manager breaks it into 4 sub-tasks, dispatches them.
4. Workers run in parallel, write results to `~/blocks-shared/<session>/results/`, signal completion.
5. Manager aggregates and reports back in the main chat.

Supports both modes:
- **Flat** — N independent panes, no coordination, you drive each
- **Manager** — 1 Manager + N Workers, file-based coordination, no duplication of work

[→ Full docs in `skills/agentic/blocks/SKILL.md`](./skills/agentic/blocks/SKILL.md)

---

## Install

```bash
# Hermes Agent
cp skills/agentic/blocks/SKILL.md ~/.hermes/skills/blocks/SKILL.md

# Or install everything at once
cp -r skills/* ~/.hermes/skills/

# Claude Code / Cursor / OpenClaw — equivalent path
# (each agent framework has its own skills dir; check docs)
```

Restart your agent session and the skill is active. Trigger it by saying any of the keywords in its `description:` field.

---

MIT · [github.com/hooooolea/agent-skills](https://github.com/hooooolea/agent-skills)

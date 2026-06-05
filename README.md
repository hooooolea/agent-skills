English | [中文](README_zh.md)

<div align="center">

# Agent Skills

_A curated collection of Hermes Agent SKILL.md files — drop-in skills for parallel-agent orchestration, blog writing, multi-agent MVPs, Spring Boot testing, and more._

![Built for Hermes · MIT licensed](https://img.shields.io/badge/Hermes-Agent-blue)

</div>

---

## What's Here

Each skill is a single `SKILL.md` file you can drop into `~/.hermes/skills/<name>/` (or your agent's equivalent) and use immediately. No npm install, no Python venv, no API keys — just markdown that teaches your agent when to use the skill and how to do it well.

| Skill | Category | One-liner |
|-------|----------|-----------|
| **[session-summary](./SKILL.md)** | productivity | Checkpoint any agent session into a `.session_summary.md`; next session resumes instantly |
| **[blocks](./skills/agentic/blocks/SKILL.md)** | agentic | Spawn N parallel Hermes agents in tmux panes — flat (independent) or manager (coordinated) |
| **[multi-agent-mvp-startup](./skills/agentic/multi-agent-mvp-startup/SKILL.md)** | agentic | Bootstrap a multi-agent MVP project (backend + frontend) |
| **[ejuerz-blog-writing](./skills/productivity/ejuerz-blog-writing/SKILL.md)** | productivity | Write and publish English AI-tooling blog posts for ejuerz.com (Astro 6 + AdSense) |
| **[dev-task](./skills/productivity/dev-task/SKILL.md)** | productivity | 5-phase multi-subagent dev workflow (decompose → explore → code → review → ship) |
| **[spring-boot-mybatisplus-unit-test](./skills/development/spring-boot-mybatisplus-unit-test/SKILL.md)** | development | Spring Boot + MyBatis-Plus service-layer unit testing with Mockito |

Browse by category: [`agentic/`](./skills/agentic/) · [`productivity/`](./skills/productivity/) · [`development/`](./skills/development/)

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

## Featured: session-summary

Your AI agent gets dumber the longer a session runs. It forgets early details, repeats itself, drifts off track. Starting fresh means re-explaining everything.

**Session Summary** fixes this. One file. One habit. Zero lost context.

```bash
# End of session — checkpoint
"Summarize the session and write .session_summary.md"

# Next session — resume instantly
"Read .session_summary.md and resume from where we left off"
```

### What Gets Saved

| Section | What It Tracks |
|---------|---------------|
| Project Overview | What you're building, tech stack, key context |
| Completed Actions | What was done, exact file paths, results |
| Current State | Where work stopped, active blockers |
| Next Steps | Priority-ordered todo for the next session |
| Known Issues | Gotchas discovered and workarounds found |

Every entry is specific — file paths, line numbers, commands that worked. No vague "we worked on the thing."

![Blog write-up on ejuerz.com](assets/blog-preview.png)

[→ Full docs in `./SKILL.md`](./SKILL.md)

---

## Install

**One file per skill.** Pick the one you want, copy its `SKILL.md` into your agent's skills directory:

```bash
# Hermes Agent
cp skills/agentic/blocks/SKILL.md ~/.hermes/skills/blocks/SKILL.md

# Or install everything at once
cp -r skills/* ~/.hermes/skills/

# Claude Code / Cursor / OpenClaw — equivalent path
# (each agent framework has its own skills dir; check docs)
```

Restart your agent session and the skill is active. Trigger it by saying any of the keywords in its `description:` field.

## Why a single-file skill format

- **Diff-friendly** — skills are markdown, not code. PRs read like documentation.
- **No dependencies** — your agent reads markdown, doesn't `pip install`.
- **Reusable** — same skill works across Hermes, Claude Code, Cursor, OpenClaw, anything that loads SKILL.md.
- **Versioned with the prompt** — when you change your agent's system prompt, you re-read the same skill; no sync drift.

## Contributing

Add a new skill:
1. Create a folder: `skills/<category>/<your-skill-name>/`
2. Add a `SKILL.md` with the required frontmatter (`name`, `description` ≤ 1024 chars, version, author)
3. Add a row to the index table in this README
4. Open a PR

See any existing `SKILL.md` for the format and tone.

## Categories

- `agentic/` — AI agent orchestration, multi-agent workflows
- `productivity/` — writing, dev workflow, session management
- `development/` — language- and framework-specific dev tools

Add a new category by creating a folder and documenting it in the README.

---

MIT · [github.com/hooooolea/agent-skills](https://github.com/hooooolea/agent-skills)

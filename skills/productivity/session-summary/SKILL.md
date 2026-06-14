---
name: session-summary
description: "Use when the user says 'summarize', 'summary', 'save state', 'save progress', 'session summary', 'help me document', 'milestone', or 'checkpoint'. Generate a structured `.session_summary.md` file at the end of any complex session or milestone, capturing current state, next steps, and known issues so the next session can resume instantly without re-explaining the project."
disable-model-invocation: true
user-invocable: true
license: MIT
compatibility: "Agent-agnostic. Writes only to `.session_summary.md` in the project root. Pure file I/O; no CLI binding."
allowed-tools: Read, Write, Bash
metadata:
  version: 1.1.0
  author: ejuer
  hermes:
    tags: [productivity, summary, session, handoff, checkpoint]
---

# Session Summary Generator

Generate a structured `.session_summary.md` file at the end of every significant session or when the user reaches a milestone. This file enables any future agent session to resume instantly without re-explaining the project.

## When to Use

Run this skill when:
- The user says "summarize", "save state", "save progress", or "session summary"
- A complex session is ending with work still in progress
- The user hits a milestone they want to checkpoint
- Context quality is degrading and a fresh session is needed

## When NOT to Use

Skip this skill when:
- Session < 30 min and the task was trivial → no value in summarising
- The task is already complete with no follow-up needed → next session starts fresh
- The user is in the middle of an active task → wait until a natural pause or the end of the session
- There are no open issues or pending decisions to carry forward → nothing to hand off

## Output Structure

Write to `.session_summary.md` in the project root using this exact format:

```markdown
# Session Summary — [Project Name]

Created: [timestamp]
Last Agent: [agent name]

---

## Project Overview
[2-3 sentences: what this project does. The next agent can discover tech stack from
project files — focus on purpose and current direction, not tooling.]

## Current Objective
[What you're trying to accomplish. One paragraph of context, followed by the
immediate next action — file names, line numbers, what was about to happen.]

## Completed This Session
1. [Action] — `path/to/file` — Result: [what changed]
2. ...

## Pending / In Progress
- [What was started but not finished, with file paths and current state]

## Known Issues
- [Issue] — [Current status or workaround]
```

### Important: merge with existing summary

If `.session_summary.md` already exists from a prior session, read it first. Carry forward any **still-relevant** items — especially unresolved Known Issues and pending work that hasn't been completed yet. Then overwrite with the merged version. The file should always represent the latest state, but it must not lose track of long-running issues that span multiple sessions.

## Example

Here is what a good session summary looks like:

```markdown
# Session Summary — Agent Skills Repo

Created: 2026-06-14 16:00 UTC
Last Agent: Claude Code

---

## Project Overview
A collection of three open-source SKILL.md files (blocks, dev-task, session-summary)
that install on any AI agent supporting the agentskills.io spec. The repo is
published at github.com/hooooolea/agent-skills.

## Current Objective
Clean up blocks skill references and documentation after the N-flexibility
rewrite. The general spawn algorithm is done and pushed. Next: fix 12 broken
cross-reference paths in `skills/agentic/blocks/references/` where files
reference each other with an extra `references/` prefix (e.g.
`references/tmux-ops.md` should be `tmux-ops.md`).

## Completed This Session
1. Rewrote recipes.md — `skills/agentic/blocks/references/recipes.md` — replaced 5 hardcoded per-N recipes with one general algorithm (horizontal chain + select-layout tiled, any N ≥ 1)
2. Updated SKILL.md frontmatter + rules — `skills/agentic/blocks/SKILL.md` — removed "N must be even", added flexible N (1-12)
3. Updated pitfalls.md Pitfall 1 — same file — replaced "odd N cannot be equalised" with "odd N is fine — tiled handles it"
4. Updated manager-flow.md — same dir — removed "N must be even, else round up"
5. Updated tmux-grid-bug.md — same dir — updated 2 old N-specific references

## Pending / In Progress
- Fix 12 cross-reference paths in references/ files — `skills/agentic/blocks/references/{manager-flow, pitfalls, worker-execution-protocol, recipes}.md` — all use `references/xxx.md` prefix when referencing peers, creating broken `references/references/` paths
- Update session-summary SKILL.md example — currently references stale "Pending" items that are now completed
- Update SKILL.md References table — still says "5 bash recipes" but there are now 2 general recipes

## Known Issues
- macOS tmux 3.x `resize-pane` bug (pane collapses to 1 row) — worked around with tiled → resize-pane + even-vertical/even-horizontal fallback chain
- blocks --manager mode recovery still fragile on >10min detached sessions (Pitfall 18) — not addressed in this round
```

## Pitfalls

- **Writing to a subdirectory** — always `.session_summary.md` at the project root. If the working directory is a subdir (e.g. `packages/foo/`), detect the repo root first:
  ```bash
  git rev-parse --show-toplevel 2>/dev/null || pwd
  ```
  Write to that path, not the local cwd. If there is no git repo (command fails), fall back to cwd and add a `Root: [absolute-path]` line below the timestamp in the file header so the next session can locate it.
- **Including credentials** — even `[REDACTED]` for placeholders is fine; never the actual value. If the session needed `ANTHROPIC_API_KEY`, write that the env var is required and where to set it.
- **Vague next actions** — "continue work" or "finish the rest" defeats the purpose. Include specific file paths, line numbers, and what the next concrete action is. The first item under "Current Objective" should tell the next agent exactly what to type or do.
- **Discarding old issues** — if `.session_summary.md` already exists, read it before overwriting. Carry forward unresolved Known Issues and unfinished pending work. Losing cross-session context defeats the purpose of the handoff.
- **Listing every file touched** — Completed This Session should highlight outcomes, not a git log. Group related changes under one bullet. If the session touched 20 files, pick the 3-5 that matter most for understanding what changed.
- **Writing summary mid-task** — don't trigger this skill in the middle of active work. Wait until a natural pause, milestone, or the user explicitly asks.

## Verification

Before reporting done:
- [ ] File path is exactly `.session_summary.md` at the project root
- [ ] All 5 sections present: Project Overview / Current Objective / Completed This Session / Pending / Known Issues
- [ ] File paths are relative to project root (e.g. `skills/agentic/blocks/SKILL.md`)
- [ ] No actual API keys or tokens in the file
- [ ] Current Objective ends with a single concrete next action (not a list of options)
- [ ] If an old summary existed, its unresolved Known Issues are carried forward

## Rules

1. **Prioritise the next action.** The last sentence of "Current Objective" should be a single concrete step — what to do immediately upon resuming.
2. **Read before overwrite.** If `.session_summary.md` already exists, read it first. Carry forward unresolved issues and pending work. Then overwrite with the merged version — don't append.
3. **Keep it current.** The file always represents the latest state — overwrite (with carry-forward), never append.

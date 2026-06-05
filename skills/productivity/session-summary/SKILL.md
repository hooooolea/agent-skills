---
layout: default
name: session-summary-generator
description: >
  Generate structured session summaries so you never lose project context.
  At the end of any complex session, ask your agent to write a
  `.session_summary.md` file capturing current state, next steps, and
  known issues. Next session, read it and resume instantly.
triggers:
  - summarize
  - summary
  - save state
  - save progress
  - session summary
  - help me document
  - milestone
  - checkpoint
---

# Session Summary Generator

Generate a structured `.session_summary.md` file at the end of every significant session or when the user reaches a milestone. This file enables any future agent session to resume instantly without re-explaining the project.

## When to Generate

Run this skill when:
- The user says "summarize", "save state", "save progress", or "session summary"
- A complex session is ending with work still in progress
- The user hits a milestone they want to checkpoint
- Context quality is degrading and a fresh session is needed

## Output Structure

Write to `.session_summary.md` in the project root using this exact format:

```markdown
# Session Summary — [Project Name]

Created: [timestamp]
Last Agent: [agent name and model]

---

## Project Overview
[2-3 sentences: what this project is, what it does, tech stack]

## Current Active Work
[What you were working on when the session ended. Be specific — file names, line numbers, what was about to happen next.]

## Goal
[What you're trying to accomplish in the near term]

## Completed Actions
1. [Action] — File: [path] — Result: [what happened]
2. ...

## Next Steps
1. [Priority order — what to do first when resuming]
2. ...

## Known Issues
- [Issue] — [Current status or workaround]
```

## Rules

1. **Write to `.session_summary.md` in the project root.** Do not use any other filename.
2. **Never write actual API keys or credentials.** If a key is needed, note that it's required and where to set it, but write `[REDACTED]` for the value.
3. **Be specific with file paths.** Use absolute paths so the next session can find things immediately.
4. **Prioritize next steps.** The first item should be what to do immediately upon resuming.
5. **Keep it current.** Overwrite the file each time — don't append. The file should always represent the latest state.

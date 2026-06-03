<div align="center">

# Session Summary

_Checkpoint your AI agent's progress. Resume any session in seconds._

</div>

---

## What It Does

Your AI agent gets dumber the longer a session runs. It forgets early details, repeats itself, drifts off track. Starting fresh means re-explaining everything.

**Session Summary** fixes this. One file. One habit. Zero lost context.

```bash
# End of session — checkpoint
"Summarize the session and write .session_summary.md"

# Next session — resume instantly
"Read .session_summary.md and resume from where we left off"
```

## What Gets Saved

| Section | What It Tracks |
|---------|---------------|
| Project Overview | What you're building, tech stack, key context |
| Completed Actions | What was done, exact file paths, results |
| Current State | Where work stopped, active blockers |
| Next Steps | Priority-ordered todo for the next session |
| Known Issues | Gotchas discovered and workarounds found |

Every entry is specific — file paths, line numbers, commands that worked. No vague "we worked on the thing."

## Install

Drop `SKILL.md` into your agent's skills directory. Done.

Works with any agent that supports skills — Claude Code, Hermes, Cursor, OpenClaw.

## Why

| Without | With |
|---------|------|
| Agent forgets after ~50 messages | Fresh context every session, full history in the file |
| Dread closing a session | Close anytime, resume instantly |
| Re-explain your project every time | One read of the file, agent is oriented |
| No record of what was tried | Complete log of attempts, successes, and failures |

---

MIT · [github.com/hooooolea/agent-session-summary](https://github.com/hooooolea/agent-session-summary)

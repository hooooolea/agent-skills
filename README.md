# Agent Session Summary

A skill that lets your AI agent checkpoint project progress so you never lose context between sessions.

## The Problem

Long AI agent sessions degrade in quality. The agent forgets earlier details, repeats suggestions, and responses get less sharp. Starting a new session means explaining everything from scratch.

## The Fix

Drop `SKILL.md` into your agent's skills folder. At the end of any session (or at any milestone), say:

> "Summarize the session and write `.session_summary.md`"

Next session:

> "Read `.session_summary.md` and resume from where we left off"

That's it. One file, one habit, no more lost progress.

## What It Captures

- Project overview and tech stack
- What was done (with exact file paths)
- Current state and blockers
- Next steps in priority order
- Known issues and workarounds

## Works With

Any AI agent that supports skills: Claude Code, Hermes, Cursor, OpenClaw, and more.

## Install

Copy `SKILL.md` to your agent's skills directory. Done.

---

MIT

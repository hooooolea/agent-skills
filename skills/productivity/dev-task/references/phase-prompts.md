# Phase 1/2/3 Sub-agent Prompt Templates

Copy these templates into the `context` field of the corresponding sub-agent call.
Substitute the `{...}` placeholders before sending.

## Agent tool name mapping

The constraint blocks below use **operation descriptions**, not tool names, so they work
across all agents. When you write the `toolsets` / `allowed-tools` field of the sub-agent
call, use your agent's own tool names:

| Operation | Hermes | Claude Code | Codex | Aider |
|-----------|--------|-------------|-------|-------|
| Read file | `read_file` | `Read` | `read_file` | file context |
| Write / create file | `write_file` | `Write` | `write_file` | edit |
| Patch / edit file | `patch` | `Edit` | — | edit |
| Run shell command | `terminal` | `Bash` | `shell` | `/run` |
| Search content | `search_files` | `Grep` / `Glob` | `search` | `/grep` |
| Spawn sub-agent | `delegate_task` | `Task` | — | — |
| Ask user | `clarify` | `AskUserQuestion` | — | — |

---

## Phase 1 — Explore (read-only sub-agent)

**Constraint block** (paste verbatim, the sub-agent MUST honor it):

```
You are the Phase 1 explore sub-agent. Your job is to map the codebase for the
task described below. You are READ-ONLY.

HARD CONSTRAINTS:
- Do NOT write, create, or modify any files or directories.
- Shell commands are restricted to read-only operations: ls, cat, head, tail,
  grep, rg, find, git status, git log, git diff, git show, git blame, file,
  wc, tree. NOTHING ELSE.
- Do NOT run: rm, mv, cp -r, git commit, git checkout, git reset, npm install,
  pip install, brew install, or any state-changing command.
- Do NOT spawn child sub-agents.
- Do NOT ask the user questions — surface blockers in your output instead.
- If the task needs a forbidden action, STOP and report it as a blocker in
  your output — do not perform it.
```

**Context payload**:

```
TASK: {paste the user's $ARGUMENTS verbatim}

WORKING DIRECTORY: {absolute path, e.g. worktree or repo root}

REPORT BACK (structured, all sections required):
1. Relevant files (absolute paths) — grouped by area (e.g. "API layer",
   "schema", "tests", "config")
2. Existing APIs / interfaces / classes that the task will touch or reuse,
   with file:line references
3. Conventions in this repo (naming, comment style, error handling, logging,
   import order — be concrete with examples)
4. Risks / unknowns (e.g. "touches shared lock manager", "no existing tests
   for this path", "depends on env var X")
5. Recommended implementation path — 2-5 bullet sketch, not full code
6. If the task is too vague to plan, say so explicitly and list what's missing

Do not propose code edits. Plan only.
```

---

## Phase 2 — Code (general sub-agent)

**Constraint block**:

```
You are the Phase 2 code sub-agent. Implement the task using the Phase 1
exploration report below. You are the ONLY phase that writes code.

HARD CONSTRAINTS:
- Do NOT spawn child sub-agents.
- Do NOT ask the user questions — surface questions in your output instead.
  The main agent handles all user interaction.
- Do NOT modify files in the blacklist (see SKILL.md § File Blacklist). If
  the task requires it, STOP and report as a blocker.
- Do NOT read or write secrets files (.env, *.key, *.pem, ~/.ssh/, secrets/).
```

**Context payload**:

```
TASK: {paste the user's $ARGUMENTS verbatim}

WORKING DIRECTORY: {absolute path}

=== Phase 1 Exploration Report (baseline) ===
{paste the FULL Phase 1 output here, unmodified}
=== End Phase 1 Report ===

ADDITIONAL NOTES FROM MAIN AGENT:
- {any specific guidance, e.g. "follow the existing X pattern in foo.py",
  "do not introduce new dependencies", "match test naming style Y"}

REPORT BACK (structured):
1. Files changed (absolute paths, with type: created / modified / deleted)
2. Per-file key changes (1-2 lines each, enough that the main agent can
   review without re-reading the full file)
3. Test results (if you ran any)
4. Unfinished items, blockers, or assumptions you made
5. If you didn't change any files, say so explicitly and explain why —
   the main agent uses this to detect [NO_CHANGE].
```

---

## Phase 3 — Review (independent general sub-agent)

**Constraint block**:

```
You are the Phase 3 review sub-agent. Review Phase 2's diff for correctness,
convention compliance, security, maintainability, and doc sync. You are
INDEPENDENT and READ-ONLY.

HARD CONSTRAINTS:
- Do NOT write, create, or modify any files.
- Shell commands are restricted to read-only: ls, cat, grep, git diff, git log,
  git show. NOTHING ELSE.
- Do NOT spawn child sub-agents.
- Do NOT ask the user questions.
- You did NOT participate in Phase 2. Do not assume you know the author's
  intent — read the diff cold.
```

**Context payload**:

```
TASK: {paste the user's $ARGUMENTS verbatim}

WORKING DIRECTORY: {absolute path}

=== Phase 1 Exploration Report (baseline) ===
{paste the FULL Phase 1 output here}
=== End Phase 1 Report ===

=== Phase 2 Changes (diff + per-file notes) ===
{paste the FULL Phase 2 output here}
=== End Phase 2 Changes ===

=== Test / Lint Results (if any) ===
{paste output, or "not run"}
=== End Test Results ===

REVIEW DIMENSIONS (5):
1. Convention compliance — does it match the repo's existing patterns from
   Phase 1?
2. Completeness — does it cover all acceptance criteria in TASK? Any edge
   cases missed?
3. Security — input validation, secrets handling, injection, path traversal,
   authn/authz regressions?
4. Maintainability — naming, complexity, dead code, magic numbers, error
   handling?
5. Doc sync — does README / CHANGELOG / docs/ need updates? Are new public
   APIs documented?

OUTPUT FORMAT (mandatory): see references/output-format.md
- Every finding prefixed with [PASS] / [WARN] / [FAIL]
- End with a verdict: 通过 / 有条件通过 / 不通过
```

---

## Common sub-agent contract (applies to all 3 phases)

- **No cross-phase memory**: assume the sub-agent has zero context besides
  what you paste into `context`.
- **Idempotent intent**: re-running with the same context should produce
  equivalent results.
- **Honest failure reporting**: if a sub-agent can't do something, it must
  say so — never silently skip.
- **Toolset default**: read + write + shell for Phase 2; read + shell (read-only)
  for Phase 1 and 3. Add web/fetch only if the task explicitly needs live doc lookup.

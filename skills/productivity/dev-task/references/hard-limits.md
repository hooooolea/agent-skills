# Hard Limits, Error Handling & DoD (v1.4)

All guardrails enforced at Phase 0 / Phase 2 / Phase 4.

## Task Size Limits

- Max 20 files changed per `/dev-task` run; exceed → `[SCOPE_TOO_LARGE]`, ask user to split
- Max 1000 new lines; exceed → same
- Estimated >1 week (5+ modules / cross-subsystem) → mandatory split into multiple `/dev-task` runs
- Phase 1 "suggested files" > 25 → `[SCOPE_TOO_LARGE]`

## Input Quality

- `$ARGUMENTS` must contain 3 elements: goal / scope / acceptance criteria
- Missing any → `clarify` (max 2 rounds; beyond → exit)
- `$ARGUMENTS` < 10 chars → `[INPUT_TOO_VAGUE]`, exit immediately

## Environment Prerequisites (Phase 0)

- Must be in a git repo (`git rev-parse --is-inside-work-tree` true); if not → ask `git init` or exit
- Must have a project manifest (`pom.xml` / `package.json` / `requirements.txt` / `go.mod` / `Cargo.toml`); missing → `[NO_MANIFEST]`, exit
- On first run, locate build command; if not found → `clarify` whether to provide or skip (skip = `[NO_BUILD_CMD]` warning, not exit)

## File Blacklist

**Sub-agents MUST NOT modify** (unless `$ARGUMENTS` explicitly says "modify X" AND main agent confirms twice):

- `pom.xml` / `build.gradle` / `build.gradle.kts` / `package.json` / `package-lock.json` / `requirements.txt` / `go.mod` / `Cargo.toml`
- `.gitignore` / `.gitattributes` / any `.git/` file
- `CLAUDE.md` / `AGENTS.md` / `.cursorrules` / `.windsurfrules`
- `.env` / `.env.*` / `*.key` / `*.pem` / `*.p12` / `secrets/` / `credentials/`
- `Dockerfile` / `docker-compose.yml` / `Dockerfile.*`
- Agent config: `~/.hermes/`, `~/.claude/`, `~/.codex/` — any `config.yaml` / `.env` / `skills/*/SKILL.md` under these
- `node_modules/` / `target/` / `build/` / `dist/` / `.venv/`

**Sub-agents MUST NOT read**: `.env` / `.env.*` / `*.key` / `*.pem` / `*.p12` / `~/.ssh/` / `~/.gnupg/` / any `secrets/` or `credentials/` dir.

**If violated**: main agent marks `[BLOCKED]` + lists violated files + suggests manual fix.

## Sub-agent Tool Whitelist

| Phase | Toolsets | Allowed | Forbidden |
|-------|----------|---------|-----------|
| 1 (Explore) | `file, terminal, search` | `read_file`, `search_files`, terminal (read-only) | `write_file`, `patch`, `edit`, `notebook_edit`, web (unless task explicitly needs it) |
| 2 (Code) | `file, terminal, search` | `write_file`, `patch`, `read_file`, `search_files`, terminal | `delegate_task` (no nesting), `clarify`, `memory`, `send_message` |
| 3 (Review) | `file, terminal, search` | `read_file`, `search_files`, terminal (read-only) | `write_file`, `patch`, `delegate_task`, `clarify`, `memory` |

**All sub-agents**: no sub-sub-agents (`max_spawn_depth=1`), no `clarify` (ask main agent), no `execute_code`.

## Error Handling

| Tag | Trigger | Action |
|-----|---------|--------|
| `[INPUT_TOO_VAGUE]` | `$ARGUMENTS` < 10 chars | Exit, ask user to rewrite |
| `[SCOPE_TOO_LARGE]` | Files > 20 / lines > 1000 / 5+ modules | Exit, ask user to split |
| `[NO_MANIFEST]` | No project manifest | Exit, suggest init command |
| `[NO_BUILD_CMD]` | No build command + user skips | Warn (not exit), DoD build-check marked N/A |
| `[TIMEOUT]` | Sub-agent 600s timeout | Mark `[TIMEOUT]`, ask retry or skip |
| `[NO_CHANGE]` | Phase 2 produced 0 file changes | Retry 1×; 0 again → `[INCOMPLETE]` exit |
| `[FORMAT_FAIL]` | Phase 3 output missing PASS/WARN/FAIL | Retry 1× with format emphasis; fail again → main agent reviews manually |
| `[INCOMPLETE]` | Phase 3 still has FAIL / Phase 2 0 changes | Exit, list incomplete items |
| `[BLOCKED]` | Phase 4 can't fix FAIL / blacklist hit | Hand off to user, list blockers |
| `[DOD_FAIL]` | Any DoD item fails | Fix before commit prompt |

**User picks C 3× in any prompt** → `[USER_ABANDONED]` exit, hand back to user.

## Definition of Done (DoD)

Phase 4 must check all 9 items before commit prompt:

1. Changed-file list is complete (union of Phase 2 + Phase 4 fixes)
2. Phase 3 output has PASS/WARN/FAIL tags + final verdict
3. FAIL count = 0 (if > 0, `[INCOMPLETE]` exit)
4. At least one build/type-check ran and reported "build success" (or equivalent)
5. `git diff --stat` output included in final report
6. `git status` output included in final report
7. BLOCKED items (if any) listed at report top, flagged
8. Docs synced (README / CHANGELOG / `docs/`) if applicable
9. All todo items marked completed

**Any item fails** → `[DOD_FAIL]`, fix before commit.

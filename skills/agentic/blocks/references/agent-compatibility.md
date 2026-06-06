# Agent Compatibility Matrix

For each agent that works with blocks, the specific flags and mechanisms differ. This file documents the per-agent quirks so you can adapt `recipes.md` to your CLI.

Use the default (hermes) if not specified. Override `AGENT_CMD` / `AGENT_HOME` env vars.

## Quick reference

| Field | hermes (default) | claude code | codex | aider |
|-------|------------------|-------------|-------|-------|
| **AGENT_CMD** | `hermes` | `claude` | `codex` | `aider` |
| **AGENT_HOME** | `~/.hermes/` | `~/.claude/` (env: `CLAUDE_CONFIG_DIR`) | `~/.codex/` (env: `CODEX_HOME`) | per-repo `.aider.conf.yml` |
| **Profile** | `-p NAME` (full isolation) | `--settings FILE` (or edit `~/.claude/settings.json`) | `--profile NAME` (overlays `<NAME>.config.toml`) | `--config FILE` (no names) |
| **Worktree** | `-w` (auto) | `-w, --worktree [name]` (creates `<repo>/.claude/worktrees/<name>`) | ❌ not in CLI; use `git worktree add` | ❌ not supported |
| **TUI warm-up** | ~6s (prompt_toolkit) | TBD (measure with `time claude --version`) | ~0.3-0.5s (Rust + Ratatui, ~66ms median) | ~instant (prompt-toolkit REPL) |
| **Slash command** | patch `commands.py` | `~/.claude/skills/<n>/SKILL.md` (new) or `~/.claude/commands/<n>.md` (legacy) | `~/.codex/prompts/*.md` → invoke as `/prompts:<name>` | ❌ no custom registration; 40+ hardcoded |
| **Session resume** | `-c <session>` | `-c` (recent) / `-r [id\|name]` | `codex resume [--last\|<id>]` | `--restore-chat-history` |

## Usage examples

```bash
# Default (hermes)
blocks --manager

# Claude Code
AGENT_CMD=claude AGENT_HOME=~/.claude blocks --manager
# Worker pane startup: claude -p coder -w
# Slash command skill: drop SKILL.md into ~/.claude/skills/blocks/

# Codex (note: Codex is fast, reduce warm-up sleep)
AGENT_CMD=codex AGENT_HOME=~/.codex blocks --manager
# Worker pane startup: codex -p coder
# Pre-create worktrees manually (Codex CLI has no -w)

# Aider
AGENT_CMD=aider blocks --manager
# Worker pane startup: aider --config ~/.aider-pane-N.yml
# No worktree, no custom slash commands, no real profile
```

## Field notes

### Profile (per-agent isolation)

- **hermes**: `-p NAME` → isolates skills, memory, sessions, config into `~/.hermes/profiles/NAME/`. Cleanest profile system of the four.
- **claude code**: No named profiles. Workaround: `--settings FILE` per-invocation, or edit `~/.claude/settings.json` directly. Settings have 3 scopes (user, project, local) — `--setting-sources user,project,local` controls which load. ([docs](https://code.claude.com/docs/en/settings))
- **codex**: `--profile NAME` / `-p NAME` overlays `~/.codex/<NAME>.config.toml` on top of `~/.codex/config.toml`. As of 0.134.0+, the old `[profiles.X]` table syntax in a single config.toml is **deprecated**; use separate `<NAME>.config.toml` files. ([docs](https://developers.openai.com/codex/config-advanced))
- **aider**: No named profiles. Closest is `--config FILE` (one-shot) or `.aider.conf.yml` (auto-searched: git root → cwd → home). ([docs](https://aider.chat/docs/config.html))

### Worktree (per-pane git isolation)

- **hermes**: `-w` flag. Auto-creates worktree.
- **claude code**: `-w, --worktree [name]`. Creates at `<repo>/.claude/worktrees/<name>` (note: different path layout from hermes). Pairs with `--tmux` for native iTerm2 pane-per-worktree. ([docs](https://code.claude.com/docs/en/worktrees))
- **codex**: **Not in CLI.** Issue [#12862](https://github.com/openai/codex/issues/12862) (open since 2026-02) tracks the request. Workaround: `git worktree add <path> -b <branch>` manually before `send-keys`. The Codex desktop app supports worktrees natively.
- **aider**: **Not supported.** No `--worktree` flag, `gh search code worktree --repo Aider-AI/aider` returns 0 hits. Workaround: `git worktree add` manually.

### TUI warm-up (the `sleep 6` after `send-keys`)

The `sleep 6` after `send-keys "$AGENT_CMD"` in `recipes.md` is calibrated for hermes's prompt_toolkit render time. Other agents may need different waits. If role-prompt text seems to land before the prompt is ready (input gets lost), increase the `sleep` per-agent.

- **hermes**: 6s (prompt_toolkit; empirically measured).
- **codex**: ~66ms median (Rust + Ratatui + Crossterm; PR #23176, 2026-05). `sleep 0.5s` is plenty. For exact timing, use `codex --no-alt-screen` to reduce screen-state race.
- **claude code**: TBD — not documented. Measure with `time claude --version` in a real TTY. Likely 2-4s.
- **aider**: ~instant (prompt-toolkit REPL; banner appears in <100ms). `sleep 1s` is safe.

### Slash command (custom `/blocks` registration)

How to register a `/blocks` command inside an agent session. This is **per-agent mechanical work** — blocks can't do it for you.

- **hermes**: Patch `~/.hermes/hermes-agent/hermes_cli/commands.py` + `cli.py` to add a `CommandDef` and a handler. See git history for the patch; not maintained in this skill.
- **claude code**: Drop a `SKILL.md` into `~/.claude/skills/blocks/` (new format) or `~/.claude/commands/blocks.md` (legacy). Auto-loaded on next session; supports YAML frontmatter (`description`, `user-invocable`, `allowed-tools`, etc.). ([docs](https://code.claude.com/docs/en/slash-commands))
- **codex**: Drop a `.md` prompt file into `~/.codex/prompts/`. Invoke with `/prompts:blocks [args]`. **Requires restart of codex TUI** to reload. Frontmatter supports `description`, `argument-hint`, plus `$1..$9` / `$ARGUMENTS` / `$NAME` placeholders. ([docs](https://developers.openai.com/codex/custom-prompts))
- **aider**: **No custom registration mechanism.** All `/` commands are hardcoded. Workaround: `/load FILE` to replay a command sequence at launch; `--load FILE` to do the same from CLI.

### Session resume (how to pass `-c <session>` through blocks)

- **hermes**: `-c <session>` continues a specific session. Without arg, resumes most recent in CWD.
- **claude code**: `-c` (most recent in CWD), `-r [id|name]` (specific), `--fork-session` to branch into a new ID. ([docs](https://code.claude.com/docs/en/cli-reference))
- **codex**: `codex resume` (interactive picker), `codex resume --last` (most recent), `codex resume <SESSION_ID>` (specific). Non-interactive: `codex exec resume --last "follow-up prompt"`. Sessions stored in `~/.codex/sessions/`. ([docs](https://developers.openai.com/codex/cli/features))
- **aider**: `--restore-chat-history` (default off) reads `.aider.chat.history.md` (relative to git root). Or `/save` + `/load FILE` to record and replay a command sequence.

## Verified versions

- **hermes**: 1.x → 1.10.x (blocks-tested)
- **claude code**: 2.1.154 (verified 2026-06)
- **codex**: 0.134.0+ (verified 2026-06; profile syntax migration required)
- **aider**: latest from PyPI (verified 2026-06)

## Caveats

- **TUI warm-up is empirical.** The numbers above are from internal benchmarks, docs, or sub-second observations. For mission-critical timing, profile your specific agent version with `time <AGENT_CMD> --version` in a real TTY tmux pane.
- **Codex profile migration.** If you're on Codex 0.134.0+, audit any old `[profiles.X]` blocks in `~/.codex/config.toml` and split them into separate `<NAME>.config.toml` files.
- **Aider has no real "agent framework"** — it's a single-CLI tool with chat history, not a multi-session profile system. The "Profile" column for aider is best-effort; treat it as a config-preset mechanism, not isolation.
- **Verified dates are snapshots.** Agent CLIs ship updates weekly. If a flag disappears or changes, update this table from the official docs (links above).

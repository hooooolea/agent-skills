# Contributing to Agent Skills

Issues and pull requests are welcome.

## Before opening a PR

1. **Read the spec.** All SKILL.md files in this repo follow the [agentskills.io open standard](https://agentskills.io/specification). Field whitelist: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Top-level `version` / `author` / `triggers` / `when_to_use` go under `metadata.*`.
2. **Run the spec checker.** Pre-commit or pre-push:
   ```bash
   python3 ~/.hermes/skills/software-development/hermes-agent-skill-authoring/scripts/check-skill-spec.py skills/<category>/<your-skill>/SKILL.md
   ```
   Or recurse a tree:
   ```bash
   python3 .../check-skill-spec.py skills/
   ```
   0 errors required. Warnings (e.g. Claude Code's `disable-model-invocation` / `user-invocable` not in strict whitelist) are accepted — they're extension fields.
3. **No `/<name>` slash self-reference in `description`.** Claude Code's `/<name>` loader misroutes triggers that say "or types /<name>". Keep that out of the description field; document slash-command installation in the body or in a separate reference instead.
4. **Description ≤ 1024 chars, body ≤ 500 lines, body ≤ 5000 tokens.** Aim for 8-15k chars body length to match peer skills in the wild.
5. **Cross-agent compatibility.** If you mention a Hermes-specific tool name (`delegate_task`, `terminal`, `write_file`, `patch`, `read_file`, `search_files`, `clarify`, `todo`, `cronjob`) or a Hermes-specific flag (`-p`, `-w`, the `/blocks` slash command), annotate it as L3 and link to [`skills/agentic/blocks/references/agent-compatibility.md`](skills/agentic/blocks/references/agent-compatibility.md) for the claude / codex / aider equivalent.

## What makes a good new skill

- **A repeatable workflow, not a one-off task.** If you only used it once, keep it as a prompt instead of a SKILL.md.
- **5-15 line trigger phrases in the `description`.** Patterns: "Use when the user says '...', '...', or '...'." Load-bearing keywords: verbs (`实现`, `改代码`, `summarize`), nouns (`session`, `block`), and code patterns (`Agent`, `delegate_task`).
- **One paragraph "what" + 3-6 short examples + a "When NOT to use" list.** Mirror the structure of [anthropics/skills](https://github.com/anthropics/skills).
- **`references/` for detail that doesn't belong in the body.** Body should fit on one screen. Move long tables, recipes, or per-agent flag differences to `references/<topic>.md`.

## Cross-publish convention

This repo (`hooooolea/agent-skills`) is the **public source of truth**. The hermes runtime also loads from `~/.hermes/skills/`. If you change a SKILL.md, both trees should match.

End-of-session audit:
```bash
diff -r ~/agent-skills/skills/ ~/.hermes/skills/   # should be empty or have only expected additions
```

If you intentionally diverge (e.g. private hermes-only additions), keep them in a `~/.hermes/skills/extra/` subdir so the public tree stays clean.

## License

By contributing, you agree your contributions are MIT-licensed.

All 23 verified pitfalls. Numbers are stable — other docs in this skill reference them by number. For recommended tmux.conf settings covering pitfalls 5/14/15, see ../templates/tmux.conf.blocks.

## Common Pitfalls

1. **Odd N is fine — tiled handles it** — `blocks 3` / `blocks 5` / `blocks 7` all work. tiled arranges odd counts as an n+1 / n grid (e.g. 3 → top row 2, bottom 1; 5 → 3+2; 7 → 4+3). Panes in the incomplete row are the same size as the others — no stretching. For N ≥ 9, tiled produces a roughly square grid with the last row incomplete if needed. The "must be even" restriction is removed as of v1.11.0.

2. **Splitting + starting agent in the same step** — the #1 cause of uneven layouts. Always split empty shells first, resize to equal, *then* `send-keys "$AGENT_CMD"`. prompt_toolkit's TUI interferes with tmux's split heuristics if it's running while you split.

3. **Panes too small** — agent wraps long diffs/tables in tiny panes. For 2x2 use `-x 200 -y 50` minimum. For 2x3 use `-x 240 -y 50`. For 2x4 use `-x 320 -y 50`. If the user's terminal is smaller than that, drop to 2x1.

4. **Detached sessions have no size** — `tmux list-sessions -F '#{session_width}'` returns empty for a `-d` session. Always pass `-x W -y H` explicitly to `new-session`, otherwise step 3 (resize-pane) computes zero-sized panes.

5. **`base-index 1` shifts everything** — if `~/.tmux.conf` sets `set -g base-index 1` and `setw -g pane-base-index 1` (recommended for blocks), the first window is `:1` and the first pane is `:1.1`, not `:0.0`. All references in this skill assume base-index 1. If you remove it from your config, change all `:1.$i` back to `:0.$i`.

6. **Race condition on `send-keys`** — `prompt_toolkit` needs ~5-7 seconds to render the input box. Always `sleep 6` after sending `$AGENT_CMD` and before attaching. Without it, the keys land before the prompt is ready and get lost.

7. **Forgetting `Enter` after `send-keys`** — `tmux send-keys` does NOT press Enter by default. Always end with `Enter`.

8. **`attach` blocks the calling shell** — that's expected. The user is now inside tmux. Detach with `prefix + d` (default prefix is `Ctrl-b`).

9. **Killing the window from inside tmux** — `prefix + &` (with confirm) or `prefix + x` for the current pane. Either kills agent without graceful `/exit`. Prefer `prefix + d` to detach and let users resume with `blocks attach`.

10. **Panes numbered by creation order, not visual position** — after `tiled` layout, pane 1.1 may end up bottom-left, not top-left. Address by number, not position. Use `select-pane -T` to tag them with meaningful names if you need stable identifiers.

11. **Profile doesn't exist → silent fallback to default** — if the user says `-p coder` but the profile wasn't created, agent runs without isolation. Warn the user the first time a non-existent profile is requested.

12. **Stale sessions pile up** — `tmux list-sessions | grep blocks-` can show 10 zombie sessions. Use `blocks kill` to clean up.

13. **tmux not installed** — `brew install tmux` on macOS, `apt install tmux` on Linux. `blocks` should check this first and fail loud with the install command.

14. **TERM variable** — agent via prompt_toolkit needs `$TERM` set to something like `xterm-256color` or `screen-256color`. If the user is inside an old SSH session with `dumb`, rendering breaks. Suggest `export TERM=xterm-256color` before re-running.

15. **Mouse support** — by default tmux does NOT pass mouse events to panes. Without `set -g mouse on` in `~/.tmux.conf`, the user can't click to switch panes, drag borders to resize, or use the wheel to scroll history. blocks depends on this; if the user complains about "can't click", the first thing to check is tmux mouse config. The `templates/tmux.conf.blocks` snippet enables this and other recommended settings.

16. **`select-layout tiled` is destructive on 1+N layouts** — when you have 1 large pane (Manager) + N small panes (Workers), calling `select-layout tiled` afterwards will RE-COMPUTE the layout using tmux's tiled algorithm. With 3 total panes, tiled often produces "1 large left + 1 column-right that takes the full row" — completely losing the N-pane stack. Pure grid layouts (2x2, 3x3) are tolerant of tiled, but for Manager+Workers structures, ALWAYS use only `resize-pane` to enforce sizes and skip `select-layout tiled` entirely. See `references/tmux-ops.md` § Split Direction Reference for the full diagnostic.

17. **`$AGENT_CMD` has no `--system-note` flag** — earlier drafts of this skill assumed a flag like `$AGENT_CMD --system-note '...'` could inject a role prompt at startup. It doesn't exist. The verified working pattern is: send `$AGENT_CMD` to the pane, wait 6s for prompt_toolkit to render, then send the role text as the first user message via `tmux send-keys -t "$SESSION":1.$i "You are ..." Enter`. The role then becomes the first entry in the conversation history, which the agent sees and obeys.

18. **macOS tmux server crashes or gets reaped after ~10 minutes of detached running** — On macOS Sonoma/Sequoia, a `tmux new-session -d` session that holds 4 $AGENT_CMD workers (each compiling/running tests, doing heavy shell work) can crash the entire tmux server around the 10-11 minute mark. Symptoms: `tmux list-sessions` returns `no server running on /private/tmp/tmux-501/default`, all worker $AGENT_CMD subprocesses vanish, pane capture returns blank. `tmux capture-pane` and `tmux send-keys` both fail with "no server". The good news: file changes workers made have already been written to disk and survive the crash — only the panes are lost. See `references/tmux-ops.md` § Recovery for the full salvage procedure. **Mitigations baked into the skill**:
    - Cap single-round task time at **6 minutes** (hard upper bound 7) — not the 10-min default
    - Workers must **`touch done-start` within 30s** of starting — that file is the only post-mortem signal that the worker received and began the task
    - Workers must **write incremental progress into `results/worker-N.md`** even before done-final — a worker that has already written a header + first finding to the result file gives the manager usable output even if the final touch is never reached
    - After spawning the session, attach to it (or open a `tmux attach` window). launchd is much less aggressive about reaping sessions with a live client.
    - If the manager needs more than 6 min of work per round, **split into multiple rounds** rather than extending the timeout

19. **Dual-touch ordering: touch `done/worker-N-start` FIRST (liveness), touch `done/worker-N-final` AFTER writing `results/worker-N.md` (completion)** — Pitfall 22 introduced dual-touch (`start` + `final`). The ordering is **different for each**:
    - **`done/worker-N-start`**: touch FIRST (within 30s of reading the task). This is the liveness signal — if the pane crashes before doing any work, the manager knows the worker received the task.
    - **`done/worker-N-final`**: touch AFTER writing the result. If the worker touches `final` before writing and then crashes, the manager reads an empty result and reports nothing. If the worker writes first, then crashes before touching `final`, the manager sees `start` exists → checks `results/worker-N.md` → recovers partial output.
    **Correct order** (see `references/worker-execution-protocol.md`):
    > 1. `touch done/worker-N-start` (atomic liveness)
    > 2. Wait for task file, do the work
    > 3. Write result to `results/worker-N.md`
    > 4. `touch done/worker-N-final` (completion signal)
    The Manager should treat "start exists but no final" as alive-and-working or crashed-mid-round, and check `results/worker-N.md` for partial output before timing out.

20. **`resize-pane -x W -y H` after a fresh `split-window` is sometimes a no-op on macOS tmux** — one pane ends up 109x1 (squashed to 1 row) and the opposite pane takes 110x50 (the full column). This is a known tmux bug pattern when the second `split -v` is issued on a pane that has been re-balanced by a previous split.
    **Fix (verified working for 2xN pure grids):** after the splits, chain layout engines to force re-tiling:
    ```bash
    tmux select-layout -t "$SESSION" even-vertical
    tmux select-layout -t "$SESSION" even-horizontal
    tmux select-layout -t "$SESSION" tiled
    ```
    This is safe for 2x2 / 2x3 / 2x4 pure grids. **Do NOT use this chain on a 1+N Manager+Workers structure** — `tiled` is destructive there (Pitfall 16). For 1+N, stick with explicit `resize-pane` only.

21. **`#{session_width}` and `#{session_height}` return empty for a freshly-detached session** — `read W H <<< $(tmux list-panes -t "$SESSION" -F '#{session_width} #{session_height}' | head -1)` gives empty values, and any `resize-pane -x 0 -y 0` based on it is a no-op (pane collapses to 0).
    **Fix:** always **hardcode** the same dimensions you passed to `tmux new-session -x W -y H`. Don't try to read them back from a detached session. For 2x2 with `-x 200 -y 50`, the target pane size is `100×25` (border cells eat ~1-2 from each).

22. **Multi-round sessions need TWO touch files, not one** — the single `done/worker-N` touch protocol works for round 1 of a session, but round 2+ of the same `--manager` blocks session hits an ambiguity:
    - No `done/` file after N minutes → is the worker pane still alive and just slow, or did it die between rounds?
    - If it died, the Manager has no idea how far the worker got (was it reading the task, halfway through coding, or about to write the result?).
    **Fix (verified working, blocks-mgr-144650 round 2, 2026-06-05):** the task file for round-N+ workers should mandate TWO touches:
    ```bash
    # Within 30 seconds of reading the task file (heartbeat — proves the pane is alive and the worker has context)
    touch ~/blocks-shared/<session>/done/worker-N-start

    # ... do the work, write results/worker-N.md ...

    # Last step, signals "I'm done, read my result"
    touch ~/blocks-shared/<session>/done/worker-N-final
    ```
    The Manager can then tell three states apart:
    - **No start, no final** → pane is dead or never read the task
    - **Start present, no final** → worker is alive and working (or crashed mid-round)
    - **Both present** → worker finished; read the result

    The `worker-N-start` file should be touched BEFORE any heavy work, and the task file should say "CRITICAL: first action MUST be ... touching .../done/worker-N-start within 30 seconds. This protects against tmux server crash — without that touch file the manager will assume you never started." The 30-second deadline also catches the case where the worker is stuck reading/parsing the task file.

23. **Custom slash command registration: PATCH POINT varies by agent** — adding a `/blocks` (or `/<skill-name>`) command requires patching each agent's own source. Backup or fork before patching upstream-managed files.
    - **hermes**: patch lives in `$AGENT_HOME/hermes-agent/{hermes_cli/commands.py,cli.py}` (upstream working tree). `hermes update` overwrites it. Backup the diff before updating, or maintain a fork.
    - **claude code**: drop a `SKILL.md` into `~/.claude/skills/<name>/` (new) or `~/.claude/commands/<name>.md` (legacy). Auto-loaded on next session; no patching required.
    - **codex**: drop a `.md` prompt into `$AGENT_HOME/prompts/`. Invoke with `/prompts:<name> [args]`. Requires restart of codex TUI to reload.
    - **aider**: no custom-registration mechanism. All `/` commands are hardcoded.
    See `references/agent-compatibility.md` for the full per-agent slash-command matrix.

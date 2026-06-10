#!/usr/bin/env bash
# recovery-scan.sh — Salvage blocks work after tmux server death
# Usage: recovery-scan.sh <project-root> <session-name>
# Example: recovery-scan.sh ~/projects/myapp blocks-mgr-140959
#
# Install: chmod +x scripts/recovery-scan.sh && ./scripts/recovery-scan.sh <root> <session>
# (Or run directly: bash scripts/recovery-scan.sh <root> <session>)
#
# Agent-agnostic: scans files under $HOME/blocks-shared/ regardless of which AI agent
# the workers were running (hermes, claude, codex, aider all use the same protocol).

set -euo pipefail

if [ $# -lt 2 ]; then
  cat <<EOF
Usage: $0 <project-root> <session-name>

Scans for salvageable work from a blocks session whose tmux server died.
Outputs:
  1. tmux server state (crashed vs detached)
  2. shared/ directory contents (tasks, results, done markers)
  3. Files modified in project-root since the session's start marker
  4. Per-worker status (start/final touches, result file mtimes)

Example: $0 ~/projects/myapp blocks-mgr-140959
EOF
  exit 1
fi

PROJECT_ROOT="$1"
SESSION="$2"
SHARED="$HOME/blocks-shared/$SESSION"
# /tmp/blocks-mgr-session is created by the spawn recipe via `touch /tmp/blocks-mgr-session`
# immediately after mkdir of the shared directory. recovery-scan uses `find -newer` against
# it to identify files modified during the session. Conflicts are harmless (last-write wins)
# but rename to /tmp/blocks-mgr-session-$PID if running concurrent recovery scans.
START_MARKER="/tmp/blocks-mgr-session"

echo "=== Blocks Recovery Scan ==="
echo "Session:    $SESSION"
echo "Shared:     $SHARED"
echo "Project:    $PROJECT_ROOT"
echo

# 1. tmux state
echo "--- tmux state ---"
if tmux list-sessions 2>&1 | grep -q "no server"; then
  echo "tmux server is DOWN (crash confirmed)"
else
  echo "tmux server is UP — workers may just be detached, not crashed"
  echo "Re-attach: tmux attach -t $SESSION"
fi
echo

# 2. shared/ directory
echo "--- shared/ contents ---"
if [ -d "$SHARED" ]; then
  for sub in tasks results done; do
    if [ -d "$SHARED/$sub" ]; then
      echo "[$sub/]"
      ls -la "$SHARED/$sub/" 2>/dev/null | tail -n +2
    else
      echo "[$sub/] (missing)"
    fi
    echo
  done
else
  echo "shared dir not found: $SHARED"
fi

# 3. project changes since session start
echo "--- project changes since $START_MARKER ---"
if [ -f "$START_MARKER" ]; then
  find "$PROJECT_ROOT" -newer "$START_MARKER" -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/target/*" \
    -not -path "*/.git/*" \
    -not -path "*/dist/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.venv/*" \
    -not -path "*/venv/*" \
    2>/dev/null | sort
else
  echo "(no START_MARKER at $START_MARKER — can't compute time window)"
fi
echo

# 4. per-worker status
echo "--- worker status ---"
DONE_DIR="$SHARED/done"
if [ -d "$DONE_DIR" ]; then
  worker_ids=$(ls "$DONE_DIR" 2>/dev/null | sed -n 's/^worker-\([0-9]*\)\(-start\|-final\)\?$/\1/p' | sort -un)
  if [ -z "$worker_ids" ]; then
    echo "(no worker files in done/)"
  else
    for worker_id in $worker_ids; do
      start_t="—"
      final_t="—"
      result_t="—"
      [ -f "$DONE_DIR/worker-$worker_id-start" ] && start_t=$(date -r "$DONE_DIR/worker-$worker_id-start" "+%H:%M:%S" 2>/dev/null || echo "present")
      [ -f "$DONE_DIR/worker-$worker_id-final" ] && final_t=$(date -r "$DONE_DIR/worker-$worker_id-final" "+%H:%M:%S" 2>/dev/null || echo "present")
      [ -f "$SHARED/results/worker-$worker_id.md" ] && result_t=$(date -r "$SHARED/results/worker-$worker_id.md" "+%H:%M:%S" 2>/dev/null || echo "present")
      echo "  worker-$worker_id: start=$start_t  final=$final_t  result=$result_t"
    done
  fi
  echo
  echo "Status taxonomy:"
  echo "  DONE     — start + final present, result written"
  echo "  PARTIAL  — start present, final missing, result partially written"
  echo "  BLOCKED  — only start, no result progress (likely env issue)"
  echo "  DEAD     — no touches (pane never read the task)"
else
  echo "done/ dir not found: $DONE_DIR"
fi

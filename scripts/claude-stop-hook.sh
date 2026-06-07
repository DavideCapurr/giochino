#!/usr/bin/env bash
#
# claude-stop-hook.sh — Claude Code "Stop" hook for ShiftBlast.
#
# Wire this into Claude Code so that *every time the agent finishes a turn* it
# writes the ShiftBlast sentinel into the shared iCloud container. iCloud then
# syncs it to the iPhone, where AgentSignalWatcher pauses the game. This replaces
# the need to keep the standalone ShiftBlastRelay menubar app running and parsing
# session files — Claude Code itself becomes the trigger.
#
# Install (on the Mac, once):
#   Add to ~/.claude/settings.json (see docs/agent-stop-hook.md for the full
#   block):
#       {
#         "hooks": {
#           "Stop": [
#             { "hooks": [ { "type": "command",
#               "command": "/ABSOLUTE/PATH/giochino/scripts/claude-stop-hook.sh" } ] }
#           ]
#         }
#       }
#
# Design notes:
#   * Always exits 0. A hook that fails or blocks must never get in the way of
#     Claude Code finishing — pausing a phone game is strictly best-effort.
#   * Writes via temp file + atomic mv, and removes any existing sentinel first,
#     because an evicted ("dataless") iCloud file makes an in-place write hang
#     while macOS tries to re-download it.
#   * Silent on success (hooks should not spam Claude's transcript). Diagnostics
#     go to stderr only, which Claude Code surfaces only on nonzero exit.

set -uo pipefail

CONTAINER="$HOME/Library/Mobile Documents/iCloud~com~davide~shiftblast/Documents"
SENTINEL="$CONTAINER/agent-stop.flag"
REASON="${1:-agente Claude Code: risposta conclusa}"
SENT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"

# If iCloud Drive isn't set up, there's nothing we can do — bail quietly.
if [ ! -d "$HOME/Library/Mobile Documents" ]; then
  echo "claude-stop-hook: iCloud Drive non attivo, sentinella non scritta" >&2
  exit 0
fi

mkdir -p "$CONTAINER" 2>/dev/null || exit 0

ESCAPED_REASON="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
TMP="$CONTAINER/.agent-stop.flag.tmp.$$"
if printf '{"reason":"%s","sentAt":"%s"}\n' "$ESCAPED_REASON" "$SENT_AT" > "$TMP" 2>/dev/null; then
  rm -f "$SENTINEL" 2>/dev/null || true
  mv -f "$TMP" "$SENTINEL" 2>/dev/null || rm -f "$TMP" 2>/dev/null
fi

exit 0

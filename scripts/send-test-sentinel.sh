#!/usr/bin/env bash
#
# send-test-sentinel.sh — write the ShiftBlast agent sentinel into the shared
# iCloud container, so you can verify the iCloud → iOS pause path end to end
# without running Claude Code or the optional legacy relay.
#
# Usage:
#   scripts/send-test-sentinel.sh ["reason text"]
#
# Then, with the ShiftBlast iOS app open in the foreground (Premium build,
# signed into the same iCloud account with iCloud Drive enabled), the game
# should pause within a few seconds.

set -euo pipefail

CONTAINER="$HOME/Library/Mobile Documents/iCloud~com~davide~shiftblast/Documents"
SENTINEL="$CONTAINER/agent-stop.flag"
REASON="${1:-test manuale da script}"
SENT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ ! -d "$HOME/Library/Mobile Documents" ]; then
  echo "❌ iCloud Drive non sembra attivo su questo Mac (manca ~/Library/Mobile Documents)." >&2
  exit 1
fi

mkdir -p "$CONTAINER"

# Write to a fresh temp file, then atomically move it into place. This avoids
# opening the existing sentinel for write — important because an evicted
# ("dataless") iCloud file makes an in-place write hang while macOS tries to
# re-download it. Removing it first is a metadata op that doesn't trigger that.
ESCAPED_REASON="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
TMP="$CONTAINER/.agent-stop.flag.tmp.$$"
printf '{"reason":"%s","sentAt":"%s"}\n' "$ESCAPED_REASON" "$SENT_AT" > "$TMP"
rm -f "$SENTINEL" 2>/dev/null || true
mv -f "$TMP" "$SENTINEL"

echo "✅ Sentinella scritta:"
echo "   $SENTINEL"
echo "   reason: $REASON"
echo "   sentAt: $SENT_AT"
echo
echo "Con l'app ShiftBlast (Premium) aperta in primo piano e collegata allo"
echo "stesso account iCloud, il gioco dovrebbe mettersi in pausa entro pochi secondi."
echo "Log app da filtrare in Console: subsystem com.davide.shiftblast → '📡 sentinella rilevata'."

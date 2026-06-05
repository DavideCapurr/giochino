#!/usr/bin/env bash
#
# send-test-sentinel.sh — write the ShiftBlast relay sentinel into the shared
# iCloud container, so you can verify the iCloud → iOS pause path end to end
# without running the relay or a real agent.
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

# Match SentinelWriter's payload: a small JSON blob whose write bumps the
# file's modification / content-change date, which is what the iOS app watches.
ESCAPED_REASON="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
printf '{"reason":"%s","sentAt":"%s"}\n' "$ESCAPED_REASON" "$SENT_AT" > "$SENTINEL"

echo "✅ Sentinella scritta:"
echo "   $SENTINEL"
echo "   reason: $REASON"
echo "   sentAt: $SENT_AT"
echo
echo "Con l'app ShiftBlast (Premium) aperta in primo piano e collegata allo"
echo "stesso account iCloud, il gioco dovrebbe mettersi in pausa entro pochi secondi."
echo "Log app da filtrare in Console: subsystem com.davide.shiftblast → '📡 sentinella rilevata'."

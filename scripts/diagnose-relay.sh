#!/usr/bin/env bash
#
# diagnose-relay.sh — run on the Mac to check every precondition the ShiftBlast
# iCloud bridge needs to reach the iOS app, and pinpoint exactly what's wrong if
# the link isn't working. Read-only except for an optional write probe.
#
# Usage:
#   scripts/diagnose-relay.sh            # checks only
#   scripts/diagnose-relay.sh --probe    # also writes + re-reads the sentinel

set -uo pipefail

CONTAINER_ROOT="$HOME/Library/Mobile Documents/iCloud~com~davide~shiftblast"
DOCS="$CONTAINER_ROOT/Documents"
SENTINEL="$DOCS/agent-stop.flag"
PROBE=0
[ "${1:-}" = "--probe" ] && PROBE=1

pass() { printf '  ✅ %s\n' "$1"; }
warn() { printf '  ⚠️  %s\n' "$1"; }
fail() { printf '  ❌ %s\n' "$1"; FAILED=1; }
FAILED=0

echo "ShiftBlast iCloud bridge ⇆ iOS — diagnostica (Mac)"
echo

echo "iCloud Drive"
if [ -d "$HOME/Library/Mobile Documents" ]; then
  pass "iCloud Drive attivo (~/Library/Mobile Documents presente)"
else
  fail "iCloud Drive non attivo: System Settings → Apple ID → iCloud → iCloud Drive"
fi

echo "Container condiviso (iCloud.com.davide.shiftblast)"
if [ -d "$CONTAINER_ROOT" ]; then
  pass "container presente: $CONTAINER_ROOT"
  if [ -d "$DOCS" ]; then
    pass "cartella Documents presente"
  else
    warn "Documents non ancora creata — verrà creata al primo invio del plugin"
  fi
else
  warn "container non ancora provisionato: avvia l'app iOS o invia un test dal plugin da loggato in iCloud"
fi

echo "Sentinella"
if [ -f "$SENTINEL" ]; then
  pass "sentinella presente: $SENTINEL"
  MOD="$(stat -f '%Sm' "$SENTINEL" 2>/dev/null || stat -c '%y' "$SENTINEL" 2>/dev/null)"
  SIZE="$(stat -f '%z' "$SENTINEL" 2>/dev/null || stat -c '%s' "$SENTINEL" 2>/dev/null || echo 0)"
  pass "ultima modifica: $MOD"
  echo "      contenuto: $(cat "$SENTINEL" 2>/dev/null)"
  # An empty/0-byte sentinel is the tell-tale of an evicted ("dataless") iCloud
  # file: in-place writes to it hang/time out. Flag it and offer the one-liner.
  if [ "${SIZE:-0}" = "0" ]; then
    warn "sentinella VUOTA (0 byte) — probabile file iCloud incagliato/evicted; le scritture in-place vanno in timeout."
    warn "rimedio: rm -f \"$SENTINEL\"  poi rilancia send-test-sentinel.sh (la versione corrente si auto-cura)."
  fi
else
  warn "nessuna sentinella ancora: usa /shiftblast-test in Claude Code o scripts/send-test-sentinel.sh"
fi

echo "Relay opzionale in esecuzione"
if pgrep -x "ShiftBlastRelay" >/dev/null 2>&1; then
  pass "processo ShiftBlastRelay attivo"
else
  warn "ShiftBlastRelay non in esecuzione (ok: non serve per il plugin Claude Code)"
fi

if [ "$PROBE" = "1" ]; then
  echo "Write probe"
  if mkdir -p "$DOCS" 2>/dev/null && date -u +%s > "$SENTINEL.probe" 2>/dev/null; then
    sync
    if [ -f "$SENTINEL.probe" ]; then
      pass "scrittura nel container riuscita (iCloud sincronizzerà verso l'iPhone)"
      rm -f "$SENTINEL.probe"
    else
      fail "scrittura non persistita"
    fi
  else
    fail "impossibile scrivere in $DOCS"
  fi
fi

echo
if [ "$FAILED" = "1" ]; then
  echo "Esito: ❌ problemi bloccanti sopra — vanno risolti perché l'app riceva i segnali."
  exit 1
else
  echo "Esito: ✅ precondizioni Mac a posto. Con l'app iOS (Premium) in primo piano,"
  echo "       un invio dovrebbe mettere in pausa il gioco e loggare '📡 sentinella rilevata'."
fi

#!/bin/zsh
set -u

reason="${1:-claude-code}"
docs="$HOME/Library/Mobile Documents/iCloud~com~davide~shiftblast/Documents"
sentinel="$docs/agent-stop.flag"
log_dir="$HOME/Library/Logs/ShiftBlast"
log_file="$log_dir/claude-plugin.log"

log() {
  mkdir -p "$log_dir" 2>/dev/null || true
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$log_file" 2>/dev/null || true
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

notify_directly() {
  if [ ! -d "$HOME/Library/Mobile Documents" ]; then
    return 1
  fi

  mkdir -p "$docs" 2>/dev/null || return 1

  sent_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo unknown)"
  escaped_reason="$(json_escape "$reason")"
  tmp="$docs/.agent-stop.flag.tmp.$$"

  if ! printf '{"reason":"%s","sentAt":"%s","source":"claude-code-plugin"}\n' "$escaped_reason" "$sent_at" > "$tmp" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi

  rm -f "$sentinel" 2>/dev/null || true
  if ! mv -f "$tmp" "$sentinel" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi

  return 0
}

if notify_directly; then
  log "notified via iCloud sentinel reason=$reason"
  exit 0
fi

log "notification skipped: iCloud Drive unavailable reason=$reason"
exit 0

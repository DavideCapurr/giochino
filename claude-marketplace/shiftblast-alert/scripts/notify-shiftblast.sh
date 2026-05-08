#!/bin/zsh
set -u

reason="${1:-claude-code}"
helper="$HOME/.shiftblast/bin/shiftblast"
docs="$HOME/Library/Mobile Documents/iCloud~com~davide~shiftblast/Documents"
config="$docs/shiftblast-relay.json"
log_dir="$HOME/Library/Logs/ShiftBlast"
log_file="$log_dir/claude-plugin.log"

log() {
  mkdir -p "$log_dir" 2>/dev/null || true
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$log_file" 2>/dev/null || true
}

notify_with_helper() {
  if [ -x "$helper" ]; then
    "$helper" done >/dev/null 2>&1
    return $?
  fi
  return 1
}

sentinel_from_config() {
  if [ ! -f "$config" ]; then
    return 1
  fi

  sed -n 's/.*"sentinelName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config" | head -n 1
}

notify_directly() {
  sentinel_name="$(sentinel_from_config)"
  if [ -z "${sentinel_name:-}" ]; then
    return 1
  fi

  mkdir -p "$docs"
  printf '%s claude-code %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$reason" > "$docs/$sentinel_name"
}

if notify_with_helper; then
  log "notified via helper reason=$reason"
  exit 0
fi

if notify_directly; then
  log "notified directly reason=$reason"
  exit 0
fi

log "notification skipped: no helper and no pairing config reason=$reason"
exit 0

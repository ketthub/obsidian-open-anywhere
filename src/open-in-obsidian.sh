#!/usr/bin/env bash
# open-in-obsidian.sh
#
# Copy external markdown files into your Obsidian Vault's inbox folder,
# then open them in Obsidian. Never overwrites: filename collisions are
# resolved by appending a timestamp suffix.
#
# Part of: obsidian-open-anywhere
# https://github.com/ketthub/obsidian-open-anywhere
#
# Usage:
#   open-in-obsidian.sh /path/to/file1.md [/path/to/file2.md ...]

set -euo pipefail

# === Locate config ===
# The .app passes OOA_CONFIG_PATH so we always find the right config.sh next
# to the installed script. From the CLI we look next to this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${OOA_CONFIG_PATH:-$SCRIPT_DIR/config.sh}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  osascript -e 'display notification "config.sh not found. Copy config.sh.example to config.sh and edit it." with title "obsidian-open-anywhere"' || true
  echo "ERROR: config not found at $CONFIG_FILE" >&2
  echo "Hint: cp config.sh.example config.sh && edit it." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

# === Defaults (used only if config.sh leaves them unset) ===
: "${VAULT_PATH:?VAULT_PATH must be set in config.sh}"
: "${VAULT_NAME:=$(basename "$VAULT_PATH")}"
: "${INBOX_SUBPATH:=Inbox}"
: "${LOG_FILE:=$HOME/Library/Logs/obsidian-open-anywhere.log}"
: "${ALLOWED_EXTENSIONS:=md markdown txt}"
: "${SHOW_NOTIFICATIONS:=1}"

# Expand ~ in user-provided paths.
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
LOG_FILE="${LOG_FILE/#\~/$HOME}"

INBOX_DIR="$VAULT_PATH/$INBOX_SUBPATH"
mkdir -p "$INBOX_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

notify() {
  [[ "$SHOW_NOTIFICATIONS" == "1" ]] || return 0
  osascript -e "display notification \"$2\" with title \"$1\"" || true
}

url_encode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

is_allowed_ext() {
  local ext_lower="$1"
  for allowed in $ALLOWED_EXTENSIONS; do
    if [[ "$ext_lower" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ ! -d "$VAULT_PATH" ]]; then
  log "ERROR: VAULT_PATH does not exist: $VAULT_PATH"
  notify "obsidian-open-anywhere" "Vault path not found: $VAULT_PATH"
  exit 1
fi

if [[ $# -eq 0 ]]; then
  log "ERROR: no input file"
  notify "obsidian-open-anywhere" "No file provided"
  exit 1
fi

for SRC in "$@"; do
  if [[ ! -f "$SRC" ]]; then
    log "SKIP (not a file): $SRC"
    notify "obsidian-open-anywhere" "Skipped (not a file): $SRC"
    continue
  fi

  BASENAME="$(basename "$SRC")"
  STEM="${BASENAME%.*}"
  EXT="${BASENAME##*.}"
  EXT_LOWER="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

  if ! is_allowed_ext "$EXT_LOWER"; then
    log "SKIP (extension not allowed: .$EXT): $SRC"
    notify "obsidian-open-anywhere" "Skipped (.$EXT not allowed): $BASENAME"
    continue
  fi

  DST="$INBOX_DIR/$BASENAME"

  # On conflict: append timestamp; if still conflicting, append numeric suffix.
  if [[ -e "$DST" ]]; then
    STAMP="$(date '+%Y-%m-%d-%H%M')"
    DST="$INBOX_DIR/${STEM}-${STAMP}.${EXT}"
    SUFFIX=1
    while [[ -e "$DST" ]]; do
      DST="$INBOX_DIR/${STEM}-${STAMP}-${SUFFIX}.${EXT}"
      SUFFIX=$((SUFFIX + 1))
    done
  fi

  cp -p "$SRC" "$DST"
  log "COPY: $SRC -> $DST"

  REL_PATH="$INBOX_SUBPATH/$(basename "$DST")"
  ENCODED_VAULT="$(url_encode "$VAULT_NAME")"
  ENCODED_FILE="$(url_encode "$REL_PATH")"
  URL="obsidian://open?vault=${ENCODED_VAULT}&file=${ENCODED_FILE}"

  log "OPEN: $URL"
  open "$URL"
done

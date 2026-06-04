#!/usr/bin/env bash
# uninstall.sh — remove obsidian-open-anywhere from your system.
#
# This removes the installed .app and unregisters it from LaunchServices.
# It does NOT delete:
#   - your config.sh in the repo
#   - the log file (~/Library/Logs/obsidian-open-anywhere.log)
#   - any markdown files already copied into your Vault's inbox folder

set -euo pipefail

APP_BUNDLE_NAME="ObsidianOpenAnywhere.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DEST_APP="$INSTALL_DIR/$APP_BUNDLE_NAME"

if [[ ! -e "$DEST_APP" ]]; then
  echo "Not installed at $DEST_APP. Nothing to do."
  exit 0
fi

echo "→ Unregistering from LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -u "$DEST_APP" || true

echo "→ Removing $DEST_APP ..."
if rm -rf "$DEST_APP" 2>/dev/null; then
  :
else
  sudo rm -rf "$DEST_APP"
fi

echo "✅ Uninstalled."
echo ""
echo "If .md files still default to this app in Finder, right-click any .md →"
echo "Get Info → 'Open with' → pick Obsidian (or another app) → 'Change All…'."

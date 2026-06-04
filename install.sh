#!/usr/bin/env bash
# install.sh — build and install obsidian-open-anywhere
#
# What this does:
#   1. Verifies config.sh exists (you must copy from config.sh.example first).
#   2. Compiles src/ObsidianOpenAnywhere.applescript into a .app bundle.
#   3. Bundles open-in-obsidian.sh + config.sh into Contents/Resources/.
#   4. Patches Info.plist so macOS lists this app as a handler for .md files.
#   5. Installs the app to /Applications (or $HOME/Applications, see below).
#   6. Re-registers it with LaunchServices.
#
# After install:
#   - In Finder, right-click any .md file → Get Info → "Open with" →
#     pick "Obsidian Open Anywhere" → click "Change All…".
#
# Re-run this script anytime you change config.sh or the source files.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Obsidian Open Anywhere"
APP_BUNDLE_NAME="ObsidianOpenAnywhere.app"
BUILD_DIR="$REPO_DIR/build"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

cd "$REPO_DIR"

# --- 1. Check config ---
if [[ ! -f "config.sh" ]]; then
  echo "❌ config.sh not found."
  echo "   Run:   cp config.sh.example config.sh"
  echo "   Then edit config.sh and set VAULT_PATH to your Obsidian Vault."
  exit 1
fi

# Quick sanity check on config.
# shellcheck disable=SC1091
source "config.sh"
if [[ -z "${VAULT_PATH:-}" ]]; then
  echo "❌ VAULT_PATH is empty in config.sh."
  exit 1
fi
EXPANDED_VAULT="${VAULT_PATH/#\~/$HOME}"
if [[ ! -d "$EXPANDED_VAULT" ]]; then
  echo "⚠️  VAULT_PATH does not exist: $EXPANDED_VAULT"
  echo "   The install will continue, but nothing will work until you create the vault."
fi

# --- 2. Compile .app ---
echo "→ Compiling AppleScript..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
osacompile -o "$BUILD_DIR/$APP_BUNDLE_NAME" "src/ObsidianOpenAnywhere.applescript"

# --- 3. Bundle shell script + config into Contents/Resources ---
echo "→ Bundling shell script and config..."
RESOURCES_DIR="$BUILD_DIR/$APP_BUNDLE_NAME/Contents/Resources"
cp "src/open-in-obsidian.sh" "$RESOURCES_DIR/open-in-obsidian.sh"
chmod +x "$RESOURCES_DIR/open-in-obsidian.sh"
cp "config.sh" "$RESOURCES_DIR/config.sh"

# --- 4. Patch Info.plist to declare .md handling ---
echo "→ Patching Info.plist..."
INFO_PLIST="$BUILD_DIR/$APP_BUNDLE_NAME/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Markdown Document" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string md" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1 string markdown" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:2 string txt" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string net.daringfireball.markdown" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text" "$INFO_PLIST"

# Set a stable bundle identifier and display name.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.obsidian-open-anywhere.app" "$INFO_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.obsidian-open-anywhere.app" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$INFO_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${APP_NAME}" "$INFO_PLIST"

# --- 5. Install ---
DEST_APP="$INSTALL_DIR/$APP_BUNDLE_NAME"
echo "→ Installing to $DEST_APP ..."

if [[ -e "$DEST_APP" ]]; then
  rm -rf "$DEST_APP"
fi

# /Applications usually needs sudo for non-admin users; try without first.
if cp -R "$BUILD_DIR/$APP_BUNDLE_NAME" "$INSTALL_DIR/" 2>/dev/null; then
  :
else
  echo "  (need sudo to write to $INSTALL_DIR)"
  sudo cp -R "$BUILD_DIR/$APP_BUNDLE_NAME" "$INSTALL_DIR/"
fi

# --- 6. Re-register with LaunchServices ---
echo "→ Registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -f "$DEST_APP"

# Optional: clean up build artifacts.
rm -rf "$BUILD_DIR"

echo ""
echo "✅ Installed: $DEST_APP"
echo ""
echo "Next steps:"
echo "  1. In Finder, right-click any .md file → Get Info."
echo "  2. Under 'Open with', pick '$APP_NAME'."
echo "  3. Click 'Change All…' to apply to every .md file."
echo ""
echo "First launch may show a Gatekeeper warning ('unidentified developer')."
echo "Open System Settings → Privacy & Security → click 'Open Anyway'."

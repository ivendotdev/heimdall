#!/usr/bin/env bash
# Builds a universal Heimdall.app and signs it, then either installs it to /Applications and
# launches it (default) or zips it for a GitHub release (--package).
set -euo pipefail
cd "$(dirname "$0")"

MODE="install"
case "${1:-}" in
    "") ;;
    --package) MODE="package" ;;
    *) echo "Usage: $0 [--package]" >&2; exit 64 ;;
esac

APP_NAME="Heimdall"
BUNDLE_ID="dev.iven.heimdall"
APP="build/$APP_NAME.app"
INSTALLED="/Applications/$APP_NAME.app"
STAGED="/Applications/.$APP_NAME.app.new"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
LOCAL_IDENTITY="Heimdall Local Signing"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
ARCHS=(--arch arm64 --arch x86_64)

# Installs sign with your self-signed certificate when it exists, so macOS treats every rebuild
# as the same app and keeps its settings. Releases (and anyone without the certificate) get
# ad-hoc signing. SIGN_IDENTITY=... overrides both.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="-"
    if [ "$MODE" = install ] && security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
        SIGN_IDENTITY="$LOCAL_IDENTITY"
    fi
fi

swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"

if [ "$MODE" = package ]; then
    ZIP="build/$APP_NAME-$VERSION.zip"
    rm -f "$ZIP"
    # No resource forks or extended attributes, so there are no stray ._ files in the zip.
    ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
    echo "Packaged $ZIP (signed: $SIGN_IDENTITY)"
    exit 0
fi

# Only ever replace our own app, never something else that happens to be called Heimdall.
if [ -e "$INSTALLED" ]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALLED/Contents/Info.plist" 2>/dev/null || true)"
    if [ "$existing_id" != "$BUNDLE_ID" ]; then
        echo "Refusing to replace $INSTALLED: its bundle ID is '$existing_id', not $BUNDLE_ID" >&2
        exit 1
    fi
fi

# Copy first, so a failed copy leaves the installed app untouched.
rm -rf "$STAGED"
cp -R "$APP" "$STAGED"

# Quit the installed copy if it's running: signal that exact process (matched by its full
# path, so a copy running from build/ is left alone) and wait up to 5 s for it to exit.
EXECUTABLE="$INSTALLED/Contents/MacOS/$APP_NAME"
if pids="$(pgrep -f "$EXECUTABLE")"; then
    kill $pids
    for _ in {1..50}; do
        pgrep -f "$EXECUTABLE" >/dev/null || break
        sleep 0.1
    done
    if pgrep -f "$EXECUTABLE" >/dev/null; then
        echo "Heimdall is still running after 5 s; quit it from the menu bar and run this again" >&2
        rm -rf "$STAGED"
        exit 1
    fi
fi

rm -rf "$INSTALLED"
mv "$STAGED" "$INSTALLED"
# Make Launch Services notice the http/https handler right away.
"$LSREGISTER" -f "$INSTALLED"
open "$INSTALLED"

echo "Installed $INSTALLED (signed: $SIGN_IDENTITY)"

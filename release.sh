#!/usr/bin/env bash
# Publishes a new Heimdall release: bumps the version, tags and pushes it, uploads the zip to
# GitHub Releases, and points the Homebrew cask at it.
# Usage: ./release.sh <version>    e.g. ./release.sh 0.2.0
# Expects the tap cloned next to this repo (override with TAP_DIR=...).
#
# Order matters: the release is uploaded as a hidden draft and its checksum verified before it
# goes public, and the cask is only touched after that. If any step fails, the script says what
# already happened and what's left to do by hand.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
TAG="v$VERSION"
REPO="ivendotdev/heimdall"
PLIST="Support/Info.plist"
TAP_DIR="${TAP_DIR:-../homebrew-tap}"
CASK="$TAP_DIR/Casks/heimdall.rb"
ZIP="build/Heimdall-$VERSION.zip"
SHA=""

fail() { echo "$*" >&2; exit 1; }

require_clean() {
    local status
    status="$(git -C "$1" status --porcelain)" || fail "Can't read the git status of $2."
    [ -z "$status" ] || fail "$2 has uncommitted changes. Commit or stash them first."
}

# 1.2.3 -> 1002003, so versions compare as plain numbers.
version_number() {
    local IFS=.
    set -- $1
    echo $(( 10#$1 * 1000000 + 10#$2 * 1000 + 10#$3 ))
}

# Which step we're in, so a failure can report what's already public.
STEP="checks"
on_exit() {
    [ "$1" -eq 0 ] && return
    echo >&2
    case "$STEP" in
        checks)
            echo "Nothing was changed." >&2 ;;
        build)
            git checkout -- "$PLIST"
            echo "Nothing was published. $PLIST is restored; fix the problem and run again." >&2 ;;
        push)
            echo "Nothing was published, but the release commit and tag exist locally. Undo them with:" >&2
            echo "  git tag -d $TAG && git reset --hard HEAD~1" >&2 ;;
        draft)
            echo "Tag $TAG is on GitHub, but its release isn't public. Check the draft with:" >&2
            echo "  gh release view $TAG -R $REPO" >&2
            echo "Then publish it (gh release edit $TAG -R $REPO --draft=false) and update the cask by hand." >&2 ;;
        cask)
            echo "Release $TAG is public, but the Homebrew cask still points at the old version." >&2
            echo "In $CASK set version \"$VERSION\" and sha256 \"${SHA:-<sha256 of $ZIP>}\", then commit and push $TAP_DIR." >&2 ;;
    esac
}
trap 'on_exit $?' EXIT

# --- Checks: nothing is changed until all of these pass. ---
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: $0 <version>, e.g. $0 0.2.0" >&2; exit 64; }
gh auth status >/dev/null 2>&1 || fail "gh isn't logged in. Run: gh auth login"
[ -f "$CASK" ] || fail "No cask at $CASK. Set TAP_DIR to your homebrew-tap clone."
[ "$(git branch --show-current)" = main ] || fail "Switch this repo to main first."
[ "$(git -C "$TAP_DIR" branch --show-current)" = main ] || fail "Switch $TAP_DIR to main first."
require_clean . "This repo"
require_clean "$TAP_DIR" "$TAP_DIR"
git pull --ff-only
git fetch --tags
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    fail "Tag $TAG already exists."
fi
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
    fail "A GitHub release for $TAG already exists."
fi

CURRENT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
CASK_VERSION="$(sed -nE 's/^  version "(.*)"$/\1/p' "$CASK")"
[[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$PLIST has an unexpected version: $CURRENT"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "$PLIST has an unexpected build number: $BUILD"
[ "$CASK_VERSION" = "$CURRENT" ] || fail "The cask is at $CASK_VERSION but $PLIST is at $CURRENT. Fix that first."
(( $(version_number "$VERSION") > $(version_number "$CURRENT") )) || fail "$VERSION isn't higher than the current $CURRENT."

read -r -p "Release $CURRENT → $VERSION publicly on GitHub and Homebrew? [y/N] " answer \
    || fail "No answer (run it in an interactive terminal). Cancelled."
[ "$answer" = y ] || [ "$answer" = Y ] || fail "Cancelled."

# --- 1. Bump the version and build the zip. ---
STEP="build"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(( 10#$BUILD + 1 ))" "$PLIST"
./build.sh --package

# --- 2. Commit and tag, then push both together (all or nothing). ---
STEP="push"
git commit -am "Release $VERSION"
git tag "$TAG"
git push --atomic origin main "$TAG"

# --- 3. Upload as a hidden draft, check the upload, then make it public. ---
STEP="draft"
gh release create "$TAG" "$ZIP" -R "$REPO" --draft --verify-tag --title "Heimdall $VERSION" --generate-notes
SHA="$(gh release download "$TAG" -R "$REPO" -p "Heimdall-$VERSION.zip" -O - | shasum -a 256 | cut -d' ' -f1)"
[ "$SHA" = "$(shasum -a 256 "$ZIP" | cut -d' ' -f1)" ] || fail "The uploaded zip doesn't match the local build."
gh release edit "$TAG" -R "$REPO" --draft=false

# --- 4. Point the cask at the published zip. ---
STEP="cask"
git -C "$TAP_DIR" pull --ff-only
sed -i '' -E \
    -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"$/  sha256 \"$SHA\"/" \
    "$CASK"
# Exactly the version and sha256 lines must have changed, to exactly the new values.
if ! grep -qx "  version \"$VERSION\"" "$CASK" \
    || ! grep -qx "  sha256 \"$SHA\"" "$CASK" \
    || [ "$(git -C "$TAP_DIR" diff --numstat)" != "$(printf '2\t2\tCasks/heimdall.rb')" ]; then
    git -C "$TAP_DIR" checkout -- Casks/heimdall.rb
    fail "The cask edit didn't come out as expected; it's been reverted."
fi
git -C "$TAP_DIR" commit -am "heimdall $VERSION"
git -C "$TAP_DIR" push

STEP="done"
echo "Released Heimdall $VERSION: https://github.com/$REPO/releases/tag/$TAG"
echo "Update your own copy with: brew update && brew upgrade --cask heimdall"

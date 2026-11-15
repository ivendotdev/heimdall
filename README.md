# Heimdall

A tiny macOS menu-bar app that asks which browser to use every time you open a link.

Set Heimdall as your default browser. When you click a link anywhere, a small panel shows your installed browsers. Pick one with a click or a number key.

- **1–9**: open the link in that browser
- **⌘C**: copy the link
- **Esc**: dismiss

Reorder or hide browsers in **Settings** (from the menu bar icon, or by opening Heimdall again from Finder, Spotlight or your launcher).

Requires macOS 14 or later. Runs on Apple silicon and Intel.

## Install

### Homebrew

```sh
brew tap ivendotdev/tap
brew trust --cask ivendotdev/tap/heimdall
brew install --cask heimdall
```

You'll still need the one-time **Open Anyway** step below the first time you open it.

### Download

1. Download `Heimdall-<version>.zip` from [Releases](https://github.com/ivendotdev/heimdall/releases), unzip it, and move `Heimdall.app` to `/Applications`.
2. Open it. macOS will refuse, because Heimdall isn't notarized by Apple. Click **Done**.
3. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the Heimdall message. You only do this once.

### Build from source

Needs Xcode (for the universal build).

```sh
git clone https://github.com/ivendotdev/heimdall.git
cd heimdall
./build.sh
```

This builds, signs, installs to `/Applications`, and launches Heimdall. Apps you build yourself don't trigger the Gatekeeper warning.

## Set up

1. Click the binoculars icon in the menu bar and choose **Set as Default Browser**, then confirm.
2. No icon? Turn Heimdall on under **System Settings → Menu Bar**, in the list of apps allowed in the menu bar.

## Releasing

```sh
./release.sh 0.2.0
```

This bumps the version in `Support/Info.plist`, builds the zip, commits, tags and pushes, publishes the GitHub release, then updates the cask in [ivendotdev/homebrew-tap](https://github.com/ivendotdev/homebrew-tap) (expected at `../homebrew-tap`, or set `TAP_DIR`). It checks everything first and asks before publishing.

## License

[MIT](LICENSE)

# Launchpad+

[Русская версия](README.ru.md)

A faster, smarter replacement for the macOS app launcher. Search, filter and sort your apps by install source (Brew, App Store, DMG), icon color, name, date, usage, last launch or size. Lives in the menu bar, 11 languages.

## Features

- Opens with a **four-finger pinch**, **⌥Space** or the menu bar icon
- Filter by **source** (App Store, Brew, DMG, System) and by **icon color**
- Sort by name, install date, usage count, last launch, source or size
- Search, arrow keys + Enter, right-click menu, adjustable icon size
- Launch at login, language switch on the fly

## Download

1. Get the latest `.dmg` from [Releases](https://github.com/kais-blkc/launchpad_plus/releases) and drag **Launchpad+** to **Applications**.
2. First launch: macOS will say it can't verify the app (it isn't notarized). Open *System Settings → Privacy & Security → Open Anyway*, or run once:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Launchpad+.app
   ```

Requires macOS 14+ on Apple Silicon. The gesture may ask for *Input Monitoring* permission.

## Build from source

Needs Command Line Tools only (`xcode-select --install`).

```sh
git clone https://github.com/kais-blkc/launchpad_plus.git
cd launchpad_plus
make install   # build and install into /Applications
```

Other commands: `make` (rebuild and run), `make dmg` (release DMG), `make stop`.

## Usage

| | |
|---|---|
| Open / close | Pinch / spread, **⌥Space**, **Esc** |
| Search | Just type |
| Navigate | Arrows, **Enter** to launch |
| Settings (language, autostart, quit) | Gear in the top right corner or menu bar icon |

## Notes

- The gesture uses Apple's private `MultitouchSupport` API and may break after a macOS update; the hotkey keeps working.
- Launch count and last launch come from Spotlight and are not stored for every app.
- Uninstall: quit from the menu bar icon and delete the app from Applications.
- New release: change `VERSION`, then `git tag vX.Y.Z && git push origin vX.Y.Z`.

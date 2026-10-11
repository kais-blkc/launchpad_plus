# Launchpad+

[Русская версия](README.ru.md)

A native replacement for the macOS app launcher. It opens as a full-screen blurred overlay and lets you search, filter and sort your apps the way you actually want: by install source (Homebrew, App Store, manual DMG, system), by icon color, and by name, install date, usage count, last launch or size.

It lives in the menu bar (no Dock icon), is written in Swift/SwiftUI and ships in 11 languages.

## Features

- **Opens the way you expect**: four/five-finger pinch on the trackpad, or <kbd>⌥</kbd><kbd>Space</kbd>, or the menu bar icon.
- **Filter by source**: App Store, Homebrew (Cask), DMG / manual install, System — with counters.
- **Filter by icon color**: ten color groups detected from each app icon.
- **Sort** by name, install date, usage count, last launch, source or size — with a caption under each icon showing the value you sort by, and a reverse-order button.
- **Search** as you type; the first match is selected so <kbd>Enter</kbd> launches it.
- **Keyboard navigation**: arrows move the selection, <kbd>Enter</kbd> launches, <kbd>Esc</kbd> closes.
- **Context menu** (right click): Open, Show in Finder, Copy Path, Move to Trash.
- **Adjustable icon size**, smooth animations and hover effects.
- **Settings** (gear in the top right corner and the menu bar icon): language, launch at login, quit.
- **11 languages**, switched on the fly: English, 简体中文, Español, Français, Deutsch, 日本語, Português (Brasil), Русский, 한국어, Italiano, Türkçe.

## Requirements

- macOS 14 or newer, Apple Silicon
- Command Line Tools (Xcode itself is **not** required): `xcode-select --install`

## Installation

```sh
git clone <repository-url> launchpad-plus
cd launchpad-plus
make install
```

`make install` builds the app, copies it to `/Applications/Launchpad+.app` and launches it. A grid icon appears in the menu bar.

Other commands:

| Command | What it does |
|---|---|
| `make` / `make run` | Stop the running copy, rebuild and launch from `build/` |
| `make build` | Build `build/Launchpad+.app` only |
| `make stop` | Quit the running app |
| `make install` | Build and install into `/Applications` |

To start it automatically, open the menu bar icon (or the gear in the overlay) and enable **Launch at login**. Do this from the copy installed in `/Applications`.

### First launch

- The app is ad‑hoc signed and built on your machine, so Gatekeeper does not block it.
- macOS may ask for **Input Monitoring** permission for the trackpad gesture. If the gesture does nothing, allow it under *System Settings → Privacy & Security → Input Monitoring* and restart the app.
- The built-in Apps gesture can stay enabled — the Launchpad+ window opens on top of it — but turning it off under *System Settings → Trackpad → More Gestures* avoids double windows.

## Usage

| Action | How |
|---|---|
| Open | Pinch with a thumb and three fingers, or <kbd>⌥</kbd><kbd>Space</kbd>, or menu bar icon → *Show Apps* |
| Close | <kbd>Esc</kbd>, spread your fingers, click an empty area, or switch to another app |
| Search | Just start typing |
| Move selection | Arrow keys |
| Launch | Click the app, or <kbd>Enter</kbd> on the selected one |
| Filter by source | *Source* segments at the top; click one |
| Filter by color | Click a color dot; click it again to clear |
| Reset filters | *Reset filters* appears under the panel when a filter is active |
| Sort | *Sort* dropdown; the arrow button reverses the order |
| Icon size | Slider at the top right of the panel |
| App actions | Right click an app |
| Language, autostart, quit | Gear in the top right corner, or the menu bar icon |

### How the source is detected

| Source | Rule |
|---|---|
| App Store | the bundle contains `Contents/_MASReceipt/receipt` |
| Brew | the app is found in `Caskroom` (`/opt/homebrew/Caskroom`, `/usr/local/Caskroom`) |
| System | lives under `/System/`, or a `com.apple.*` bundle without an App Store receipt |
| DMG | everything else (installed from a DMG, an archive or a website) |

## Uninstall

1. Turn off **Launch at login** and choose **Quit** in the menu bar icon menu.
2. Delete `/Applications/Launchpad+.app`.
3. Optional: `defaults delete dev.launchpadplus.app` removes saved settings (language, icon size).

## Customization

- **Hotkey**: key code and modifiers in `Sources/LaunchpadPlus/AppDelegate.swift` (`hotKey.register`).
- **Gesture sensitivity**: `pinchInRatio` / `pinchOutRatio` in `Sources/LaunchpadPlus/TrackpadGesture.swift`.
- **App icon**: replace `Resources/AppIcon-source.png` (1024×1024 PNG) and run `make`. The macOS icon shape is applied automatically.
- **Translations**: `Resources/<lang>.lproj/Localizable.strings`. After editing run `scripts/check_strings.py` to verify all languages have the same keys.

## Limitations

- The trackpad gesture uses Apple's private `MultitouchSupport` framework. It may break after a macOS update; the hotkey keeps working.
- Last launch and launch count come from Spotlight metadata, which macOS does not keep for every app.
- The app is not sandboxed and cannot be published in the Mac App Store.
- Right-to-left languages are not supported yet.

## Project structure

```
Sources/LaunchpadPlus/   app code (SwiftUI + AppKit)
Resources/               Info.plist, app icon source, translations (*.lproj)
scripts/                 build.sh, make_icon.swift, check_strings.py
Makefile                 run / build / stop / install
```
# launchpad_plus

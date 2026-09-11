# Soundrift

**Soundrift** is a lightweight macOS menu bar utility for switching audio input and output devices with a global keyboard shortcut.

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?style=flat-square)](#requirements)
[![Release](https://img.shields.io/github/v/release/skndmx/Soundrift?style=flat-square)](https://github.com/skndmx/Soundrift/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/skndmx/Soundrift/total?style=flat-square)](https://github.com/skndmx/Soundrift/releases)

<p align="center">
  <img src="TripleS/Assets.xcassets/AppIcon2.imageset/1024-mac.png" alt="Soundrift icon" width="128" />
</p>

<p align="center">
  <img src="docs/images/main-window.png" alt="Soundrift main window — Devices, Shortcuts, and Settings tabs" width="880" />
</p>

## Why Soundrift?

macOS makes it easy to *change* the default audio device — and tedious to do it often. Soundrift keeps your preferred devices in a short list and lets you cycle them instantly from the keyboard, without opening System Settings.

Built for people who hop between headphones, speakers, and mics all day.

## Features

| | |
|---|---|
| **Global shortcuts** | Separate hotkeys for output rotation, input rotation, and mute |
| **Menu bar app** | Stays out of the way; close the window to hide the Dock icon |
| **Hide clutter** | Tuck away virtual devices (Teams Audio, etc.) |
| **Launch at login** | Ready when you are |

## Install

1. Download the latest **`.dmg`** from [Releases](https://github.com/skndmx/Soundrift/releases/latest)
2. Open the disk image and drag **Soundrift** into **Applications**
3. Launch Soundrift — look for the headphones icon in the menu bar

### Gatekeeper note

Current releases are **ad-hoc signed** (not notarized). If macOS says the app is damaged or blocked:

```bash
xattr -cr /Applications/Soundrift.app
```

Then right-click the app → **Open**.

## Quick start

1. Open **Show Main Window** from the menu bar icon  
2. On **Devices**, check the outputs/inputs you want in rotation  
3. Open **Shortcuts** and record hotkeys with **Change**  
4. Press the shortcut to switch — a notification confirms the active device  

**Tips**

- Eye icon → hide a device; restore it from **Hidden**  
- Volume for the active device lives in the top strip when macOS exposes it  
- **⌘W** (or the red close button) → back to menu-bar-only mode  
- Quit from the menu bar when you want Soundrift fully exited  

## Requirements

- macOS **26** or later  
- Bundle ID: `com.kevinjin.Soundrift`

## Building from source

```bash
git clone https://github.com/skndmx/Soundrift.git
cd Soundrift
open TripleS.xcodeproj
```

Run the **TripleS** scheme in Xcode (the app product is named **Soundrift**).

```bash
# Optional: local DMG
./scripts/create-dmg.sh
# → dist/Soundrift-<version>.<build>.dmg
```

## Contributing

Issues and pull requests are welcome. For bugs, include your macOS version and a short description of the audio setup (built-in / Bluetooth / virtual devices).

## License

This project is licensed under the [MIT License](LICENSE).

---

Made by [Kevin Jin](https://github.com/skndmx)

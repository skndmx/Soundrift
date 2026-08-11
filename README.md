# Soundrift

A macOS menu bar app for quickly switching audio input and output devices.

**Requirements:** macOS 26+  
**Bundle ID:** `com.kevinjin.Soundrift`

## Features

- Switch between selected output and input devices with global keyboard shortcuts
- Menu bar access — runs in the background after you close the window
- Hide devices you don’t need (e.g. virtual audio devices)
- Auto-switch to a device when it connects
- Auto-reconnect paired Bluetooth devices (useful on Macs without an Apple ID)
- Launch at login

## Install

Download the latest DMG from [Releases](https://github.com/skndmx/TripleS/releases), open it, and drag **Soundrift** to Applications.

If Gatekeeper warns that the app is damaged or can’t be opened (unsigned builds), clear quarantine and open once via right-click:

```bash
xattr -cr /Applications/Soundrift.app
```

## Usage

1. Open Soundrift from the menu bar (**Show Main Window**)
2. On the **Output** / **Input** tabs, check the devices you want in your rotation
3. Set a keyboard shortcut for each tab
4. Use the shortcut to cycle devices — a notification shows the active device

Optional (per device, bolt icon):

- **Auto-switch when connected** — set as system default when the device appears
- **Auto-reconnect Bluetooth** — retry connecting a paired Bluetooth device (pair it first in System Settings → Bluetooth)

Hide clutter with the eye icon; restore devices from the **Hidden** section.

Close the window with **⌘W** or the red button to return to menu-bar-only mode (no Dock icon). Quit from the menu bar when you want to fully exit.

## Develop

Open `TripleS.xcodeproj` in Xcode 26+ and run the **TripleS** scheme (product name: Soundrift).

```bash
# Local release DMG
./scripts/create-dmg.sh
# → dist/Soundrift-<version>.<build>.dmg
```

Release process (tagging, GitHub Actions, signing notes): see [RELEASE.md](RELEASE.md).

## Reset local preferences

```bash
defaults delete com.kevinjin.Soundrift
```

## License

Private project by Kevin Jin.

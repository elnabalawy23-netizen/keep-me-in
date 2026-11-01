# Keep Me In

A tiny macOS menu bar app that keeps your Microsoft Teams presence on **Available**.

Teams flips you to *Away* after five minutes without keyboard or mouse input. Keep Me In watches the same idle clock and, once you have been quiet for a configurable interval (default 60 s), posts one invisible nudge: the pointer moves one pixel and straight back (or F15 is tapped, a key no Mac keyboard has). While you are actually typing or moving the mouse it does nothing. It also holds a "keep display awake" assertion so the Mac never locks itself.

## Install on any Mac

```bash
curl -fsSL https://raw.githubusercontent.com/elnabalawy23-netizen/keep-me-in/main/install.sh | bash
```

If the repository is private, sign in to GitHub CLI first (`brew install gh && gh auth login`), then run the same line. The script downloads the latest release, puts it in /Applications, clears the quarantine flag, and launches the app.

First launch on each Mac: allow Keep Me In under System Settings → Privacy & Security → Accessibility. That is once per Mac. Updates installed with the same script keep the permission, because every release is signed with the same certificate.

## Requirements

- macOS 14 Sonoma or newer (built and tested on macOS 26.2 Tahoe)
- To build: Swift 6 toolchain from Xcode **or** the Command Line Tools (`xcode-select --install`)
- Accessibility permission (macOS asks on first launch)

## Build, sign, release

```bash
make cert       # once per build machine: creates the local signing certificate (asks for your password once)
make app        # builds build/Keep Me In.app signed with that certificate
make run        # build + launch from build/
make install    # build + copy to /Applications + launch
make release    # build + zip + publish a GitHub release for the version in Packaging/Info.plist
make dev        # swift run, no bundle, for quick iteration
make watch-idle # live HID idle counter, handy to confirm nudges land
```

To ship a new version: bump `CFBundleShortVersionString` in `Packaging/Info.plist`, commit, run `make release`. Other Macs pick it up by re-running the install line.

### Why the certificate matters

macOS ties the Accessibility grant to the app's code signature. An ad-hoc signature changes with every build, so every update used to look like a brand-new app and the grant silently stopped working. `make cert` creates a self-signed code-signing certificate in your login keychain (backed up in `~/.keepmein-signing/`). Every build signed with it has the same designated requirement, so macOS keeps trusting updates. It is not an Apple Developer ID, which is why the installer clears the quarantine flag instead of relying on Gatekeeper. If you ever add a paid Developer ID, the build script picks it up automatically and prefers it.

To sign from a second Mac, copy `~/.keepmein-signing/` there and run `make cert`; it imports the saved certificate instead of creating a new one. Creating a *new* certificate would reset the grant one more time on every Mac.

## Features

- Menu bar panel with live status, idle time, countdown to the next nudge, nudge counter, Teams state, and display state
- Mouse nudge or F15 mode
- Interval 15 s to 4 min
- Keep the display awake while active
- Only run while Microsoft Teams is running
- Pause while the screen is locked
- Schedule: hours and weekdays
- Launch at login
- Self-check that reports when nudges stop registering

## Layout

```
Package.swift                 SwiftPM manifest (macOS 14+, Swift 5 language mode)
Sources/KeepMeIn/
  KeepMeInApp.swift           MenuBarExtra + Settings scenes
  Engine/ActivityEngine.swift 1 Hz loop: gating, nudging, self-check, published state
  Engine/InputSimulator.swift CGEvent posting (mouse nudge / F15)
  Engine/IdleMonitor.swift    System idle clock + "real" idle that ignores our own events
  Engine/PowerAssertion.swift IOPM display-sleep assertion
  Engine/*.swift              Permissions, Teams detection, screen lock, schedule, login item
  Settings/AppSettings.swift  Persisted preferences
  Views/                      Menu panel and Settings window
Packaging/Info.plist          Bundle metadata (LSUIElement = menu bar only)
Packaging/make-icon.swift     Draws the app icon with AppKit
scripts/build-app.sh          Assembles and signs the .app
```

## Troubleshooting

**Clicks act like double clicks or open a context menu.** Check whether macOS thinks a modifier is held:

```bash
swift -e 'import CoreGraphics; let f = CGEventSource.flagsState(.hidSystemState); print(String(f.rawValue, radix: 16), f.contains(.maskControl) ? "control stuck" : "ok")'
```

Tap the left Control key and the Globe/Fn key once each to clear it. Versions before 1.0.1 posted nudges with the HID system state source and the default 250 ms local-event suppression, which could swallow half of a click or a modifier release that happened right as a nudge fired. Current builds use the combined session source, zero suppression, clean flags on every synthetic event, and skip the nudge while any modifier or mouse button is physically held.

**"Accessibility access needed" although the app is listed and switched on.** The entry belongs to a build signed differently (ad-hoc builds before `make cert`, or a build from another certificate). Select it, press −, press + and add the app again, or run `tccutil reset Accessibility com.omarelnabalawy.KeepMeIn` and click "Grant access…" in the panel.

## Development

- `make dev` runs the bare executable without a bundle (useful for quick iteration; the Dock icon and app icon are missing in that mode).
- `KEEPMEIN_SNAPSHOT_DIR=/tmp/shots .build/debug/KeepMeIn` renders every screen (menu panel and the three settings tabs, light and dark) to PNG files and exits. Handy for reviewing UI changes without opening the app.
- `make watch-idle` prints the system HID idle timer once a second. When a nudge lands you see it drop back to zero.

## How it works

Teams (an Electron app) reads `CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType)`. Events posted with `CGEventPost(kCGHIDEventTap, …)` reset that clock, which is what the nudge does. Posting synthetic input is why the Accessibility permission is needed. Nothing leaves your Mac; there is no network code at all.

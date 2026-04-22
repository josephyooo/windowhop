# WindowHop

> **Note**: This project was built with [Claude Code](https://claude.ai/claude-code). Code, documentation, and commit messages were AI-generated with human direction and review.

A tiny macOS menu bar agent for moving the focused window to another display. Trigger it with a hotkey, pick a display from a spatial overlay (think macOS Display → Arrange…), and the window jumps there — centered, at a reasonable size.

Built for multi-display setups where dragging a window across screens or remembering Mission Control corners is more friction than the move itself.

## How it works

1. Hotkey fires `open -g windowhop://show` (via Raycast, Shortcuts, or any launcher that can run a shell command).
2. WindowHop captures the currently focused window, then shows a non-activating overlay with each display drawn in its real spatial arrangement. The overlay appears on the same display as the focused window (falling back to the cursor's display, then the main display, if the window's frame can't be read).
3. Pick a display with arrow keys + return, or press its number. The window is moved there via the Accessibility API and centered at a reasonable size.
4. Fullscreen / non-movable windows play a Tink and bail.

## Install

Requires macOS 14+ and a Swift toolchain.

```sh
./build.sh
mv WindowHop.app /Applications/
open /Applications/WindowHop.app   # first launch — grant Accessibility
```

The first launch shows a welcome window walking through Accessibility permission. WindowHop registers itself in the Accessibility list silently — no unsolicited TCC prompts — and the menu bar icon shows a warning state until the permission is granted.

## Triggering it

WindowHop has no built-in hotkey; bind one with whatever launcher you use. The URL scheme is `windowhop://show`.

A Raycast Script Command is included:

```sh
ln -s "$PWD/raycast/windowhop.sh" ~/path/to/your/raycast/scripts/
```

Or from the shell:

```sh
open -g windowhop://show
```

## Inside the overlay

- Arrow keys — move selection spatially across displays
- `1`–`9` — pick a display by number and commit
- Return — commit the current selection
- Esc — dismiss without moving

## Repo layout

- `Sources/windowhop/` — Swift sources (SwiftPM target)
  - `main.swift` — entry point + `--export-icon` CLI used by the build script
  - `AppDelegate.swift` — menu bar, overlay lifecycle, URL-scheme handling
  - `WindowMover.swift` — Accessibility-API window capture + move
  - `WelcomeWindow.swift` — first-run permission flow
  - `WindowHopIcon.swift` — Core Graphics icon, used for both the menu bar template image and the app icon
- `Resources/Info.plist` — agent (`LSUIElement`) bundle, `windowhop://` URL scheme
- `build.sh` — `swift build`, render the iconset by invoking the binary in `--export-icon` mode, run `iconutil`, assemble the `.app`, ad-hoc codesign
- `raycast/windowhop.sh` — Raycast Script Command

## Notes

- WindowHop is an `LSUIElement` agent — no Dock icon, just the menu bar item.
- The overlay is a non-activating `NSPanel` so the previously focused application stays frontmost; the focused window is captured before the panel appears.
- Ad-hoc codesigning means the binary's hash changes on every rebuild and TCC may need a fresh grant. WindowHop nudges the system into re-registering on launch, so usually just toggling the Accessibility entry off/on is enough.

## Context

The current Mac Host implementation uses an `NSPopover` with a SwiftUI view. The user has requested to revert to the original, simpler interface.

## Goals / Non-Goals

**Goals:**
- Restore `NSMenu` as the primary interaction method.
- Remove SwiftUI and `NSPopover` related logic.
- Maintain existing WebSocket and mDNS functionality.

**Non-Goals:**
- Reverting the iPhone Client UI (the user specifically mentioned `mac/VocalHostApp.swift`).

## Decisions

- **Restore AppDelegate Logic**: Revert `AppDelegate` to use `@main` as a class delegate and manage an `NSStatusItem` with an `NSMenu`.
- **Dynamic Menu Updates**: Re-implement the `updateMenu()` function to refresh the connection status string in the menu.

## Risks / Trade-offs

- **Visual Simplification**: The UI will become less "modern" but will regain the simplicity of a standard macOS menu.

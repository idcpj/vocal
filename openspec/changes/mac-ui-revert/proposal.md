## Why

The recent UI refactor on the Mac Host, although more visually rich, involves additional complexity and may not align with the user's preference for simplicity. To return to a more stable and lightweight interface, we are reverting the Mac Host UI to its original `NSMenu`-based implementation.

## What Changes

- **Mac Host UI Restoration**: Replace the `NSPopover` and SwiftUI-based `VocalMenuView` with the original `NSMenu` and `NSMenuItem` structure.
- **Simplification**: Remove SwiftUI dependency and `NSPopover` management logic from `AppDelegate`.
- **Status Reporting**: Return to updating the status item's menu dynamically based on connection state.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `custom-menu-view`: Reverting this capability to use native `NSMenu` instead of a custom view.
- `ui-state-sync`: Updating the synchronization to target the standard menu items.

## Impact

- **Mac**: `mac/VocalHostApp.swift` will be restored to its previous state.
- **Dependencies**: No longer requires SwiftUI for the menu logic.

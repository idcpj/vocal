## Why

The initial UI implementation was a functional proof-of-concept. To provide a more cohesive and professional user experience, we are refactoring both the Mac Host menu and the iPhone Client interface based on a refined design system (Pencil nodes `1VIet` and `t0xxC`). This refactor ensures visual consistency, better spacing, and a more robust component structure.

## What Changes

- **Mac Host UI Refactor**: Transformation of the menu bar dropdown from a standard `NSMenu` to a custom view-based layout (`1VIet`) with dedicated header, status, and action sections.
- **iPhone Client UI Refactor**: Update the Flutter application with a more structured layout (`t0xxC`), including a refined header, a centered main action area, and a distinct transcription background container.
- **Styling Alignment**: Unified use of specific background colors (`#1E293B` for Mac, `#0A0F1C` for iPhone) and layout constraints (padding, corner radii) defined in the design specs.

## Capabilities

### New Capabilities
- `custom-menu-view`: Implementation of a custom `NSView` for the Mac menu bar dropdown to support rich layouts and custom styling beyond standard `NSMenuItem`.

### Modified Capabilities
- `ui-state-sync`: Update the UI refresh logic to support the new component-based layout and ensuring all labels/icons react to connection and transcription states as designed.

## Impact

- **Mac**: `mac/VocalHostApp.swift` will be significantly modified to replace `NSMenu` logic with `NSPopover` or a custom `NSView` attached to the status item.
- **iPhone**: `mobile/lib/main.dart` will be updated to match the new widget hierarchy and styling.
- **Design System**: New design tokens (colors, spacing) will be formalized in the codebase.

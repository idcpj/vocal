## Context

The current UI implementation is a basic Flutter Scaffold and a standard macOS NSMenu. While functional, it lacks the premium "Terminal × Minimal" aesthetic defined in the design system. We have specific Pencil designs (Mac: `1VIet`, Mobile: `t0xxC`) that structure the interfaces into more robust component hierarchies.

## Goals / Non-Goals

**Goals:**
- Implement a custom, rich UI for the Mac menu bar dropdown using a custom View or Popover.
- Update the mobile client with a refined layout and distinct transcription section.
- Achieve visual parity with the Pencil design nodes.
- Maintain existing WebSocket and mDNS communication protocols.

**Non-Goals:**
- Modifying the underlying communication logic or STT processing (unless required for state reporting).
- Adding new features beyond UI/UX improvements.

## Decisions

- **Mac (NSPopover)**: Instead of a simple `NSMenu`, we will use an `NSPopover` to host a custom `NSView` (via `NshostingView` if using SwiftUI, or direct `NSView` for pixel-perfection). This allows for complex layouts like the header, status, and action sections seen in node `1VIet`.
- **Mobile (Component Separation)**: The Flutter `main.dart` will be refactored to separate the `VocalHomeScreen` into smaller widgets or clear `Row`/`Column` blocks that match node `t0xxC`'s structure (Header, Main, Transcription Background).
- **Theme Centralization**: Introduce a style guide-derived constant or theme object to manage the electric cyan and slate colors consistently.

## Risks / Trade-offs

- **Mac Accessibility**: Custom menu views can sometimes interfere with standard accessibility reporting if not managed correctly. We will ensure the `Check Permissions` logic remains prominent.
- **Wireless Performance**: Complex UI updates during high-frequency text injection might impact perceived latency. We will use efficient UI refresh patterns.

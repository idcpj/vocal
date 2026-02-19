## ADDED Requirements

### Requirement: Custom Menu View (Mac)
The Mac Host SHALL replace the standard `NSMenu` with a custom `NSView` (or hosted SwiftUI view) displayed within an `NSPopover`.

#### Scenario: Display custom menu
- **WHEN** the user clicks the menu bar status item
- **THEN** the app SHOULD display a popover containing a header, connection status info, and action buttons as defined in Node `1VIet`.

### Requirement: Structured Layout (Mobile)
The iPhone Client SHALL organize its UI into a distinct header, a centered microphone interaction zone, and a bottom-aligned transcription container.

#### Scenario: Visual separation of transcription
- **WHEN** speech is recognized
- **THEN** the text SHOULD appear within a specialized background container (`transcription_bg`) at the bottom of the screen as defined in Node `t0xxC`.

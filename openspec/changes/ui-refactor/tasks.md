## 1. Mac Host UI Refactor

- [x] 1.1 Implement `NSPopover` and `NSViewController` to replace `NSMenu`.
- [x] 1.2 Design the custom menu view layout per Pencil Node `1VIet` (Header, Status, Actions).
- [x] 1.3 Update `AppDelegate` to toggle popover on status item click.
- [x] 1.4 Connect status indicators in the new view to reactive state updates.

## 2. iPhone Client UI Refactor

- [x] 2.1 Refactor `main.dart` to use a more structured widget hierarchy (Header, Main, Bottom Transcription).
- [x] 2.2 Re-style the app using the new background colors and padding rules from node `t0xxC`.
- [x] 2.3 Implement the specialized `transcription_bg` container with improved typography.
- [x] 2.4 Add subtle micro-animations (e.g., pulsing mic) for the centered interaction zone.

## 3. Integration & Testing

- [x] 3.1 Verify UI responsiveness on both platforms during active streaming.
- [x] 3.2 Ensure accessibility permissions workflow still functions within the new custom Mac view.
- [x] 3.3 Final visual polish and design system alignment.

## Why

The current `injectText` implementation in `VocalHostApp.swift` attempts to set the `kAXValueAttribute` of the focused UI element. This approach is problematic because:
1. It often overwrites the entire content of the text field instead of inserting at the cursor.
2. Many applications do not support setting the value attribute directly via accessibility.

To achieve a "Remote Keyboard" experience, we need to simulate actual keystrokes at the system level.

## What Changes

- **Simulated Typing**: Replace `AXUIElementSetAttributeValue` with a `CGEvent`-based implementation that simulates keyboard events for each character.
- **Support for Special Characters**: Ensure that Unicode characters (like Chinese or symbols) are correctly handled using `keyboardSetUnicodeString`.
- **System-Wide Injection**: Post events to the `combinedSessionState` so they work globally.

## Capabilities

### New Capabilities
- `cursor-text-injection`: Ability to inject text exactly where the Mac cursor is currently active.

## Impact

- **Mac**: `mac/VocalHostApp.swift` (specifically the `injectText` function).

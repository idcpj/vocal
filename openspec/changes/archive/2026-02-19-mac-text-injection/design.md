## Goals

- Implement character-by-character text injection that works at the current cursor position.
- Support multi-byte Unicode strings (e.g., Emojis, Chinese characters).
- Maintain responsiveness of the Mac host while typing.

## Decisions

- **Use CoreGraphics Events**: Utilize `CGEvent` with `keyboardSetUnicodeString` to post keyboard events.
- **Event Source**: Use `.combinedSessionState` to ensure events are dispatched to the currently active application.
- **No Accessibility Required**: This method does not strictly require the user to enable Accessibility permissions for *value setting*, although it's still good practice to have them checked for other potential AX features.

## Technical Details

```swift
func injectText(_ text: String) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for char in text.utf16 {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
```

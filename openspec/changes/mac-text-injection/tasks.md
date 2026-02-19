## 1. Implementation

- [ ] 1.1 Import `CoreGraphics` (implicitly included in `Cocoa` but good to keep in mind).
- [ ] 1.2 Replace `AXUIElementSetAttributeValue` logic in `injectText` with `CGEvent` simulated typing.
- [ ] 1.3 Add optional logic to handle system "Return" or "Space" if needed for speech-to-text separation.

## 2. Verification

- [ ] 2.1 Re-compile `VocalHost`.
- [ ] 2.2 Open a text editor (Notes, TextEdit, etc.) on the Mac.
- [ ] 2.3 Speak into the iPhone and verify text appears at the cursor without overwriting.

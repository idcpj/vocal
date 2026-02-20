## 1. Implementation

- [x] 1.1 Refine `_onSpeechResult` in `lib/main.dart` with a robust delta guard (length fallback).
- [x] 1.2 Update `_startListening` to reset both `_lastWords` and `_lastSentWords`.
- [x] 1.3 Implement `List<String> _historyList` and append `finalResult` transcriptions.
- [x] 1.4 Update UI to show `_lastWords` using `RichText` (green sent text) with divergence handling.
- [x] 1.5 Add a scrollable history section to the mobile UI.

## 2. Verification

- [ ] 2.1 Verify that transcription no longer "stops" after a few words.
- [ ] 2.2 Verify that the sent prefix turns green, even after minor engine corrections.
- [ ] 2.3 Verify that text clears on new session and saves to History.

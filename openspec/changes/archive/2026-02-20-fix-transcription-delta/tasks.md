## 1. Implementation

- [x] 1.1 Add `_lastSentWords` state to `_VocalHomeScreenState` in `mobile/lib/main.dart`.
- [x] 1.2 Implement delta calculation logic in `_onSpeechResult`.
- [x] 1.3 Update `_startListening` to reset `_lastSentWords`.
- [x] 1.4 (Optional) Add a debounce or normalization to handle rapid whitespace updates.

## 2. Verification

- [x] 2.1 Speak several words slowly and verify only new text is injected.
- [x] 2.2 Speak a long sentence and verify no duplication occurs on Mac.
- [x] 2.3 Verify that restarting a listening session works correctly.

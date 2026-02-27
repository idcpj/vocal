## 1. Logic Implementation

- [ ] 1.1 Add `_isFinalizing` guard and track `_lastFinalizedText` in `VocalHomeController`
- [ ] 1.2 Update `_finalizeSentence` to use the guard and deduplicate consecutive identical strings
- [ ] 1.3 Ensure `_onSpeechResult` cancels debounce timer correctly and respects the guard

## 2. Verification

- [ ] 2.1 Manually verify that saying "123" only types "123" once on the Mac
- [ ] 2.2 Verify that saying different sentences works as expected
- [ ] 2.3 Verify that saying the same sentence with a pause works as expected

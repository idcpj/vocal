# Delta Spec: Speech Recognition - Deduplication

## Proposed Context
The current implementation of speech recognition in the mobile app sometimes sends the same transcribed sentence multiple times to the host Mac. This occurs when the silence timeout and the official final result event overlap.

## Requirements

### [MODIFIED] deduplication
- **ID**: `speech-recognition.deduplication`
- **Description**: The `VocalHomeController` shall ensure that the same recognized string is not sent to the Mac host more than once per recognition event.
- **Verification**: Verify that saying "123" results in "123" being typed exactly once on the host Mac, regardless of whether the silence timer or the plugin's final result fires first.

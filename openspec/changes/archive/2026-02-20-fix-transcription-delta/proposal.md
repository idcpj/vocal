## Why

Currently, the iPhone client sends the entire accumulated `recognizedWords` string on every update. Since the STT engine provides incremental cumulative updates, the Mac Host receives "Hello", then "Hello how", then "Hello how are", resulting in "Hello Hello how Hello how are" being injected into the Mac application.

## What Changes

- **Delta Tracking**: Maintain a `_lastSentWords` state in the Flutter app.
- **Suffix Calculation**: On each `onSpeechResult` callback:
    1. Check if `recognizedWords` still starts with `_lastSentWords`.
    2. If it does, extract the new suffix (the "delta").
    3. Send only the delta to the Mac Host.
    4. Update `_lastSentWords`.
- **Reset Logic**: Reset `_lastSentWords` to an empty string when starting a new listening session to handle non-incremental restarts.

## Capabilities

### Modified Capabilities
- `speech-recognition`: Refining the data transmission logic.

## Impact

- **iPhone**: `mobile/lib/main.dart`

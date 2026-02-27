# Proposal: Fix Duplicate Text Sending

Each recording currently sends duplicate text (e.g., saying "123" results in "2323" on the Mac). This is likely caused by the overlap between the silence-detection debounce timer and the official "final result" event from the `speech_to_text` plugin, both of which trigger the `_finalizeSentence` logic.

## Goal
Ensure each recognized sentence is sent to the Mac exactly once.

## Proposed Changes

### Mobile (Flutter)
- **File**: `mobile/lib/page/vocal_home_controller.dart`
- **Changes**:
  - Implement a guard to prevent `_finalizeSentence` from processing the same text twice.
  - Improve the interaction between the debounce timer and `finalResult` handling.
  - Possibly keep track of the last successfully sent string to avoid immediate duplicates.

## What Changes
Added logic to deduplicate outgoing messages in the `VocalHomeController`.

## Capabilities

### Modified Capabilities
- `speech-recognition`: Improve reliability by preventing duplicate text injection on the host Mac.

## Impact
- **Affected code**: `VocalHomeController` in the mobile app.
- **Side effects**: None expected, should only reduce noise.
- **Dependencies**: No new dependencies.

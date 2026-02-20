## Why

Users reported duplicate text on session completion and requested visual feedback for sent text. Current delta logic logic may be re-sending full sentences if the engine restarts or emits a "final" result that isn't handled incrementally by the current logic.

## What Changes

- **Incremental Logic**: Refine `_onSpeechResult` to calculate the delta more strictly. If the new result doesn't start with the previously sent text (implying a restart or correction), we will handle it by only sending the new content that overlaps or follows the last finalized state.
- **Stop Guard**: Add a guard to ensure that calling `stop()` doesn't trigger a redundant final transmission of the entire buffer.
- **Session Reset**: Deeply reset `_lastWords` and `_lastSentWords` whenever a new listening session starts.
- **History Feature**: Add a `List<String> _historyList` to store finalized results and display them in a scrollable list.
- **UI Enhancement**:
    - Update the transcription display to distinguish between "already sent" (green) and "pending/partial" (default).
    - Use `RichText` with `TextSpan` for this visual distinction.

## Capabilities

### Modified Capabilities
- `speech-recognition`: Refining incremental sync and UI representation.

## Impact

- **iPhone**: `mobile/lib/main.dart`

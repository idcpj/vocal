## Context
The `VocalHomeController` uses a debounce timer to detect silence and finalize sentences. It also listens for the `finalResult` flag from the `SpeechToText` plugin. When both events occur in rapid succession, `_finalizeSentence` is called twice, leading to duplicate text being sent to the Mac host.

## Goals / Non-Goals

**Goals:**
- Prevent duplicate text from being sent to the Mac host.
- Maintain the "auto-finalize on silence" behavior.
- Ensure "finalResult" from the plugin is still handled promptly.

**Non-Goals:**
- Changing the Mac host's text injection logic.
- Implementing a full-blown state machine for STT (yet).

## Decisions

### 1. Guard against duplicate finalizations
We will introduce a `_isProcessingFinalization` flag or a timestamp-based guard. However, a more robust approach is to check if the text to be sent is identical to the text that was *just* finalized, while allowing the same text to be sent again if it's part of a *new* recognition cycle.

### 2. Synchronized Finalization
We will ensure that if `_finalizeSentence` is called, it cancels any pending debounce timers and ignores redundant calls for the same payload.

### 3. State Management
We will use a `String? _lastFinalizedText` to keep track of the last sentence sent during the current "wants listening" session. This will be reset when a new session starts or when the user stops listening.

## Risks / Trade-offs
- **Risk**: If the user legitimately says the same thing twice rapidly, it might be ignored.
- **Mitigation**: We only guard against identical text sent within a very short timeframe or before the "done" status is received and the engine restarts.

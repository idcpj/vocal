# Design: Remote Voice Keyboard Architecture

## Context
Traditional voice-to-text on Mac often feels disconnected from the user's primary mobile device, which typically has better microphones and specialized AI processing. This design bridges the gap by making the iPhone a high-fidelity remote input peripheral.

## Goals / Non-Goals

**Goals:**
- **Low Latency**: Text should appear on Mac near-simultaneously with speech.
- **Accuracy**: Leverage iOS native SFSpeechRecognizer.
- **Ease of Use**: Auto-discovery and zero-config pairing.

**Non-Goals:**
- Supporting raw audio streaming (Option A was discarded).
- Cross-platform support for the Mac side (Swift/AppKit will be used for best integration).

## Decisions

### 1. Communication Protocol: WebSocket + mDNS
- **Rationale**: WebSockets provide a full-duplex, low-latency connection. mDNS (Bonjour) allows the iPhone to find the Mac on the local network without IP manual entry.
- **Fallback**: BLE will be kept as a secondary target if local Wi-Fi is unavailable.

### 2. Speech Processing: iOS Native SFSpeechRecognizer
- **Rationale**: Provides high-quality, on-device (for supported languages) STT with low power consumption and privacy. It handles adaptive volume and noise cancellation natively.

### 3. Mac Text Injection: Accessibility API (AXUIElement)
- **Rationale**: While `CGEvent` can simulate keys, `AXUIElement` and the `NSAIDictationInput` interfaces allow for smoother "insertion" of text chunks, preserving the undo stack and multi-caret support in some apps.

## Technical Architecture

### Component Diagram (Mermaid)
```mermaid
graph TD
    subgraph iPhone (Flutter)
        UI[Flutter UI] --> STT[SFSpeech Service]
        STT --> WS_Client[WebSocket Client]
    end
    
    subgraph Mac (Swift)
        WS_Server[WebSocket Server] --> Handler[Text Handler]
        Handler --> AX[Accessibility API]
        AX --> App[Target Application]
    end
    
    WS_Client -- "JSON (Text + Metadata)" --> WS_Server
```

## Risks / Trade-offs

- **Risk**: Connectivity stability on crowded Wi-Fi.
  - **Mitigation**: Implement robust a handshake and reconnection logic.
- **Trade-off**: Native Mac App vs Electron.
  - **Decision**: Native Swift ensures better system integration for Accessibility and lower resource footprint.

## 1. Implementation

- [x] 1.1 Add `heartbeatTimer` to `AppDelegate` in `VocalHostApp.swift`.
- [x] 1.2 Implement `startHeartbeat` and `sendPing` on Mac.
- [x] 1.3 Add `_lastHeartbeat` and heartbeat check timer in Flutter `lib/main.dart`.
- [x] 1.4 Implement `{"type": "pong"}` response in Flutter.

## 2. Verification

- [x] 2.1 Observe "Heartbeat started" in Mac logs.
- [x] 2.2 Observe "Received ping, sent pong" in Flutter debug logs.
- [x] 2.3 Simulate disconnect and verify status updates to OFFLINE.

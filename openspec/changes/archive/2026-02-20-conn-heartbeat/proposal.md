## Why

Currently, the connection status is only updated during the initial handshake. If the network drops or one app crashes, the other side may still show as "Connected." A heartbeat mechanism ensures that the connection status remains accurate and the system can self-recover.

## What Changes

- **Active Monitoring**: Implement a ping/pong mechanism.
- **Mac Server**: Periodically send a small JSON heartbeat packet (`{"type": "ping"}`) every 5 seconds.
- **iPhone Client**: Respond immediately with `{"type": "pong"}` and maintain a "last received" timestamp.
- **Auto-Update UI**: Both sides will revert to a "Searching" or "Waiting" state if the heartbeat is lost for more than 10 seconds.

## Capabilities

### Modified Capabilities
- `websocket-protocol`: Extending the protocol to include heartbeat messages.

## Impact

- **Mac**: `mac/VocalHostApp.swift`
- **iPhone**: `mobile/lib/main.dart`

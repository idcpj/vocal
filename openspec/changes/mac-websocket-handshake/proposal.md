## Why

The Mac Host is currently using a raw TCP listener, but the iPhone Client is sending WebSocket-specific handshake requests (HTTP GET with `Upgrade: websocket`). Because the Mac Host doesn't handle the WebSocket protocol, the handshake never completes, preventing the connection from becoming functional and leave the UI stuck in a "Waiting" state.

## What Changes

- **Upgrade to WebSocket Protocol**: Configure `NWListener` in `VocalHostApp.swift` to use `NWProtocolWebSocket`.
- **Handshake Management**: Automate the WebSocket handshake using the native Network framework capabilities.
- **Message Decoding**: Use `receiveMessage` to retrieve framed WebSocket messages instead of raw TCP byte streams.
- **UI State Update**: Ensure `isConnected` is set only after the WebSocket connection is truly ready.

## Capabilities

### Modified Capabilities
- `websocket-server`: Upgrading from raw TCP to full WebSocket support.

## Impact

- **Mac**: `mac/VocalHostApp.swift`

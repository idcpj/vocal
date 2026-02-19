## 1. Implementation

- [x] 1.1 Add `NWProtocolWebSocket` configuration to `NWParameters` in `startWebSocketServer`.
- [x] 1.2 Update `newConnectionHandler` to monitor WebSocket lifecycle state.
- [x] 1.3 Refactor `receive` to `receiveMessage` for framed WebSocket content.

## 2. Verification

- [x] 2.1 Re-compile and run `VocalHost`.
- [x] 2.2 Observe `VocalHost.log` for successful handshake completion.
- [x] 2.3 Verify the Mac UI status updates to "Connected".

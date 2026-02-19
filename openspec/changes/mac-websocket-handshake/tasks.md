## 1. Implementation

- [ ] 1.1 Add `NWProtocolWebSocket` configuration to `NWParameters` in `startWebSocketServer`.
- [ ] 1.2 Update `newConnectionHandler` to monitor WebSocket lifecycle state.
- [ ] 1.3 Refactor `receive` to `receiveMessage` for framed WebSocket content.

## 2. Verification

- [ ] 2.1 Re-compile and run `VocalHost`.
- [ ] 2.2 Observe `VocalHost.log` for successful handshake completion.
- [ ] 2.3 Verify the Mac UI status updates to "Connected".

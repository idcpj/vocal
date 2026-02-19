## Context

The Mac Host receives HTTP requests from the iPhone client but fails to upgrade them to WebSocket because it is listening on raw TCP.

## Goals

- Upgrade the server to use `NWProtocolHeader` with `NWProtocolWebSocket`.
- Automate the WebSocket handshake.
- Set `isConnected = true` only when the WebSocket state is truly `ready`.

## Decisions

- **Protocol Stack**: Insert `NWProtocolWebSocket.Options()` into the `NWParameters.tcp` protocol stack.
- **Connection Handler**: Explicitly check for `connection.stateUpdateHandler` to monitor transition to `.ready`.
- **Legacy Removal**: Remove raw string parsing of HTTP headers from the `receive` logic.

## Verification

- **Log Check**: Look for "WebSocket connection ready" in `VocalHost.log`.
- **UI State**: The status item menu should update to "Status: Connected".

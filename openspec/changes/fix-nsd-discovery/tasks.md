## 1. Mac Host Fixes

- [x] 1.1 Update `NetService` type to `_vocal._tcp` (no trailing dot) in `VocalHostApp.swift`.
- [x] 1.2 Implement `netServiceDidPublish` and `netService(_:didNotPublish:)` delegate methods.
- [x] 1.3 Add diagnostic print statements to verify publication success.

## 2. iPhone Client Fixes

- [x] 2.1 Update `_discoverServices` in `lib/main.dart` to handle service resolution explicitly if needed.
- [x] 2.2 Add logging for discovered services, including their host and port.
- [x] 2.3 Ensure the connection is only attempted when `host` and `port` are non-null.

## 3. Verification

- [x] 3.1 Re-compile and run Mac Host, checking for "Service published" log.
- [x] 3.2 Re-run iPhone app in debug mode.
- [x] 3.3 Verify in logs that the service is found and the connection is established.

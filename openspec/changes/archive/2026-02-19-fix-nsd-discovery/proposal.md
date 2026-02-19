## Why

The current implementation of service discovery using NSD/mDNS is failing to establish a connection between the Mac Host and the iPhone client. This prevents the primary functionality of using the phone as a microphone. We need to ensure that the service is correctly advertised on the Mac and discovered/resolved on the iPhone.

## What Changes

- **Mac Host Service Advertisement**: Refine the `NetService` publication to ensure it uses the standard naming conventions and handles delegates for error reporting.
- **iPhone Discovery Logic**: Enhance the `nsd` discovery transition to include explicit service resolution and improve error handling for cases where hostnames are returned instead of IP addresses.
- **Entitlement Verification**: Ensure all necessary "Local Network" permissions and Bonjour service types are correctly declared in the iOS `Info.plist`.

## Capabilities

### New Capabilities
- `reliable-discovery`: Ensuring that the local network discovery works across different network configurations.

### Modified Capabilities
- `mdns-service-discovery`: Correcting the service type and resolution logic.

## Impact

- **Mac Host**: `mac/VocalHostApp.swift`
- **iPhone Client**: `mobile/lib/main.dart`, `mobile/ios/Runner/Info.plist`

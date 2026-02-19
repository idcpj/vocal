## Context

The Mac Host uses `NetService` to advertise its presence, and the iPhone uses the `nsd` Flutter package to discover it. Currently, the connection is not being established, likely due to a failure in service resolution or a mismatch in expected service type strings.

## Goals / Non-Goals

**Goals:**
- Guarantee reliable discovery of the Mac Host on the local network.
- Provide clear logging for the publication and discovery process.
- Resolve the Mac's IP address correctly on the iPhone.

**Non-Goals:**
- Switching to a different discovery mechanism (like hardcoding IPs).

## Decisions

- **Mac Host Improvements**: 
    - Implement `NetServiceDelegate` methods (`netServiceDidPublish`, `netService(_:didNotPublish:)`) to log the publication status.
    - Use `_vocal._tcp` (no trailing dot) for the type in `NetService` to be consistent with the Flutter discovery type.
- **iPhone Client Improvements**:
    - Update the `nsd` listener to wait for IP resolution.
    - Add more detailed logging to the UI or console during the discovery phase.
- **Info.plist Update**:
    - Ensure `NSBonjourServices` matches the advertised type exactly.

## Risks / Trade-offs

- **Network Environment**: mDNS can be blocked by certain router settings or host firewalls. We should advise the user to check these if the software fix doesn't work.

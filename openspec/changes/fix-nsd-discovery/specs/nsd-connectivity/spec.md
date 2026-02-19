## MODIFIED Requirements

### Requirement: mDNS Service Publication (Mac)
The Mac Host SHALL publish its service type as `_vocal._tcp` (standard name) and MUST implement and log the results of the publication delegates.

### Requirement: Service Discovery and Resolution (iPhone)
The iPhone Client SHALL discover services of type `_vocal._tcp` and MUST ensure the service is resolved to an IP address before attempting a WebSocket connection.

#### Scenario: Successful Discovery and Connection
- **GIVEN** the Mac Host is advertising `_vocal._tcp` on port 8080
- **WHEN** the iPhone Client discovers the service
- **AND** the service is resolved to a valid IP/host
- **THEN** the iPhone Client SHALL initiate a WebSocket connection to `ws://<resolved-host>:8080`.

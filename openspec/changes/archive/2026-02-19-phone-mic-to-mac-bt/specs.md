## ADDED Requirements

### Requirement: Service Discovery (mDNS)
The Mac Host SHALL broadcast its presence on the local network using mDNS (Bonjour) with the service type `_vocal._tcp`.

#### Scenario: iPhone discovers Mac
- **WHEN** the iPhone app starts and searches for local services
- **THEN** it SHOULD list all available Mac hosts running the Vocal service

### Requirement: Communication (WebSocket)
The Mac Host SHALL run a WebSocket server to receive text payloads from the iPhone.

#### Scenario: Real-time text sync
- **WHEN** the iPhone sends a transcribed text chunk over the WebSocket
- **THEN** the Mac Host SHOULD receive the payload with a latency of less than 100ms

### Requirement: Speech-to-Text Processing
The iPhone Client SHALL use the iOS native `SFSpeechRecognizer` for real-time transcription.

#### Scenario: Continuous transcription
- **WHEN** the user holds the "Push to Talk" button
- **THEN** the app SHOULD stream transcription results to the UI and the connected Mac Host simultaneously

### Requirement: Mac Text Injection
The Mac Host SHALL inject received text into the currently active text field using macOS Accessibility APIs (`AXUIElement`).

#### Scenario: Text insertion in active app
- **WHEN** a text payload is received from the iPhone
- **THEN** the Mac Host SHOULD insert that text at the current cursor position in the frontmost application

### Requirement: UI State Synchronization
The iPhone UI SHALL reflect the current connection and transcription state.

#### Scenario: Visual feedback during recording
- **WHEN** the "Push to Talk" button is active
- **THEN** the UI SHOULD show the "Live Transcription" area with the streaming text and a blinking cursor

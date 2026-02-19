## MODIFIED Requirements

### Requirement: UI State Synchronization
The UI state synchronization SHALL be extended to support complex component-based state reporting.

#### Scenario: Update custom menu status
- **WHEN** the connection state changes
- **THEN** the custom Mac menu view SHOULD update its status label and header icon dynamically.

#### Scenario: Visual feedback on iPhone Client
- **WHEN** audio is being captured
- **THEN** the centered microphone zone SHOULD provide visual feedback (e.g., pulsing or glow) while displaying the live transcription in the bottom container.

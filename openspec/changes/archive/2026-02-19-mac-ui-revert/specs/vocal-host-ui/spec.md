## MODIFIED Requirements

### Requirement: Mac Host UI (Standard Menu)
The Mac Host SHALL use a standard `NSMenu` attached to an `NSStatusItem` for its primary user interface.

#### Scenario: Display standard menu
- **WHEN** the user clicks the menu bar status item
- **THEN** the app SHOULD display an `NSMenu` with status information and action items.

#### Scenario: Update connection status
- **WHEN** the connection state changes
- **THEN** the menu SHALL be updated to reflect the new status (e.g., "Status: Connected" or "Status: Waiting...").

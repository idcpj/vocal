## Why
Currently, `VocalHost` requires manual compilation and command-line execution. This is a barrier for non-developer users and lacks the professional feel of a macOS application. Providing a `.dmg` installer makes the app more accessible and follow standard macOS distribution patterns.

## What Changes
- Create a standard macOS `.app` bundle structure.
- Automate the build and packaging process with a script.
- Generate a `.dmg` installer containing the app bundle.
- Update documentation to reflect the new installation workflow.

## Capabilities

### New Capabilities
- `macos-app-bundling`: Creating a valid `.app` directory structure with `Info.plist` and necessary metadata.
- `dmg-installer-generation`: Automated generation of a disk image (.dmg) for application distribution.

## Impact
- **Code**: No changes to core application logic in `VocalHostApp.swift`.
- **Packaging**: New files for bundle configuration (`Info.plist`) and build orchestration (`build_macos.sh`).
- **User Experience**: Signficantly improved installation and first-run experience.

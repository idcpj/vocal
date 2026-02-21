# Capability: dmg-installer-generation

## Requirements
The system must be able to generate a macOS Disk Image (.dmg) for distribution.

### 1. Image Format
- The output must be a file named `VocalHost.dmg`.
- It should use the UDZO format (compressed read-only) for distribution.

### 2. Content
- The `.dmg` must contain the `VocalHost.app` bundle created by the `macos-app-bundling` process.
- It should ideally provide a visual hint for installation (dragging to Applications), though a simple file inclusion is acceptable for the first version.

### 3. Generation Process
- The process must use native macOS tools (`hdiutil`).
- It must be repeatable and automated via the build script.

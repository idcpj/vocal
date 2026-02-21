# Capability: macos-app-bundling

## Requirements
The system must be able to bundle the `VocalHost` Swift application into a standard macOS `.app` bundle.

### 1. Bundle Structure
- The output must be a directory named `VocalHost.app`.
- It must contain the following subdirectories:
  - `Contents/MacOS/`
  - `Contents/Resources/`
- The compiled binary must reside in `Contents/MacOS/VocalHost`.

### 2. Metadata (Info.plist)
- An `Info.plist` file must be present in `Contents/`.
- It must define at least:
  - `CFBundleExecutable`: `VocalHost`
  - `CFBundleIdentifier`: `com.idcpj.vocalhost`
  - `CFBundleName`: `VocalHost`
  - `CFBundlePackageType`: `APPL`
  - `LSUIElement`: `1` (to indicate it's an accessory/menu bar app)

### 3. Build Orchestration
- A build script must exist that automates the compilation and placement of files.
- The script should handle ad-hoc code signing (`codesign -s -`) to allow the app to run on the local machine without notarization.

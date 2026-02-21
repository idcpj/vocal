## Context
The `VocalHost` app is currently a single Swift source file (`mac/VocalHostApp.swift`) that uses `@main`. It is compiled via `swiftc`. Packaging it into an `.app` bundle is necessary for it to be recognized as a GUI application by macOS and for distributing it via a `.dmg`.

## Goals / Non-Goals

**Goals:**
- Automate the creation of a standard macOS `.app` bundle.
- Generate a `.dmg` installer using only native macOS tools.
- Ensure the app can be easily copied to the `/Applications` folder.

**Non-Goals:**
- Setting up a full Xcode project (unnecessary for this simple host).
- Notarization (requires an Apple Developer Program membership and active internet connection).
- Custom DMG background or icons (kept for future enhancement).

## Decisions

### 1. Build Orchestration via Shell Script
We will use `mac/build_macos.sh` instead of an Xcode project. This keeps the repository lightweight and allows for easy CI/CD integration.
- **Rationale**: The project is simple enough that `swiftc` is sufficient.

### 2. Custom Info.plist
We will provide a manual `Info.plist` template.
- **Rationale**: Necessary to define the app's bundle ID and behavior (specifically `LSUIElement` for the menu bar app status).

### 3. DMG Creation via hdiutil
We will use a sequence of `hdiutil create`, `hdiutil attach`, `cp`, and `hdiutil detach` to create the DMG.
- **Rationale**: Avoids external dependencies like `create-dmg` while still producing a valid disk image.

## Risks / Trade-offs

- **[Risk] Gatekeeper Warnings** → Ad-hoc signing will still trigger warnings on other Macs.
  - **Mitigation**: Add a note in the README about right-clicking to open for the first time or granting permission in Security settings.
- **[Risk] Permissions** → The app relies on Accessibility APIs which require user approval.
  - **Mitigation**: The app already includes a "Check Permissions" button and a prompt in its logic.

## Migration Plan
- Users who previously used the command-line version can simply replace it with the new `.app` bundle.
- The `VocalHost` binary from the previous build process can be removed or overwritten.

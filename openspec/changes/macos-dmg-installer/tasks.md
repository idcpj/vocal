## 1. Setup

- [x] 1.1 Create `mac/Info.plist` template with app metadata.
- [x] 1.2 Initialize `mac/build_macos.sh` script with basic configuration.

## 2. Core Implementation

- [x] 2.1 Add Swift compilation command to `build_macos.sh`.
- [x] 2.2 Add `.app` bundle structure creation logic to `build_macos.sh`.
- [x] 2.3 Add ad-hoc codesigning to the build script.
- [x] 2.4 Add DMG generation logic using `hdiutil` to `build_macos.sh`.

## 3. Documentation & Verification

- [x] 3.1 Update `README.md` and `README_zh.md` with the new installation method.
- [x] 3.2 Execute `build_macos.sh` and verify the output artifacts.
- [x] 3.3 Verify the application runs correctly from the newly created DMG.

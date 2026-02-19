## 1. Code Restoration

- [x] 1.1 Remove SwiftUI imports and the `@main` struct from `VocalHostApp.swift`.
- [x] 1.2 Restore `AppDelegate` as the `@main` entry point and class-based structure.
- [x] 1.3 Remove `NSPopover` and `VocalMenuView` definitions.
- [x] 1.4 Restore the `updateMenu()` function using `NSMenu` and `NSMenuItem`.

## 2. Logic Cleanup

- [x] 2.1 Re-bind the status item button to the standard menu dropdown.
- [x] 2.2 Ensure connection status updates trigger the `updateMenu()` call correctly.
- [x] 2.3 Verify that `Check Permissions` and `Quit` menu items are functional.

## 3. Verification

- [x] 3.1 Compile and run the Mac Host application.
- [x] 3.2 Verify the status item displays the correct icon and menu on click.
- [x] 3.3 Test connectivity with the iPhone client and verify live status updates in the menu.

## 1. Mac Host Implementation (Swift)

- [x] 1.1 Initialize macOS menu bar app with lightweight icon
- [x] 1.2 Implement mDNS service advertising (`_vocal._tcp`)
- [x] 1.3 Set up WebSocket server to receive text payloads
- [x] 1.4 Implement text injection using macOS Accessibility APIs (`AXUIElement`)
- [x] 1.5 Create dropdown menu with status indicators and permission checks

## 2. iPhone Client Implementation (Flutter)

- [x] 2.1 Integrate `speech_to_text` package with iOS native `SFSpeechRecognizer`
- [x] 2.2 Implement service discovery to find Mac hosts on the local network
- [x] 2.3 Set up WebSocket client for continuous text streaming
- [x] 2.4 Build main UI with "Push to Talk" button and live transcription area
- [x] 2.5 Implement visual feedback (cursor, status text) based on connection state

## 3. Integration & Permissions

- [x] 3.1 Verify end-to-end text sync over local network
- [x] 3.2 Ensure proper Mac Accessibility permissions flow
- [x] 3.3 Test connectivity stability and reconnection logic
- [x] 3.4 Perform final UI/UX polish on both platforms

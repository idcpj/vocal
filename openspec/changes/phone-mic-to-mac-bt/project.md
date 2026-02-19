# Project: Remote Voice Keyboard (iPhone to Mac)

## Product Overview
This project aims to provide a seamless voice-to-text bridge between an iPhone and a Mac. Users can use their iPhone as a remote "voice input" device that transcribes speech into text and instantly types it into the active cursor position on their Mac.

## Core Features

### 1. iPhone App (Flutter)
- **Push-to-Talk (PTT) Interface**: A large, easy-to-press button to start/stop voice capture.
- **Real-time Transcription**: Integration with iOS `SFSpeechRecognizer` for high-accuracy, low-latency Speech-to-Text.
- **Visual Feedback**: Real-time display of the transcribed text on the iPhone screen before/while sending.
- **Connection Wizard**: Easily pair with the Mac via QR code or auto-discovery (mDNS/Bluetooth).

### 2. Mac Companion App (Swift/Native)
- **Menu Bar Presence**: Lightweight icon showing connection status.
- **Secure Receiver**: Listen for incoming text chunks from the paired iPhone.
- **Smart Text Injection**: Automatically "types" text into the currently focused application using Accessibility APIs.
- **Permission Management**: Guide the user to enable necessary system permissions.

### 3. Connection & Security
- **Local Network Support**: High-speed syncing over Wi-Fi (WebSocket/mDNS).
- **Bluetooth (BLE) Fallback**: Ability to work even without a shared Wi-Fi network.
- **End-to-End Security**: Simple pairing mechanism to ensure only authorized devices can send text.

## User Journey
1.  **Setup**: User installs both apps.
2.  **Pairing**: User scans a QR code on the Mac using the iPhone.
3.  **Input**: User focuses a field on Mac, speaks into the iPhone, and text appears instantly.

# Proposal: Remote Voice Keyboard (iPhone to Mac)

## Goal
Enable users to use their iPhone's voice input to directly type on their Mac. This provides a fast, accurate, and ergonomic keyboard alternative, leveraging iOS speech recognition and AI to input text into any Mac application.

## What Changes
This project implements a "Remote Keyboard" architecture consisting of two components:

1.  **iPhone Client (Flutter)**: 
    - A simple UI with a "Push to Talk" button.
    - Captures voice and performs Speech-to-Text (STT) locally.
    - Sends the resulting text to the Mac over a secure connection.
2.  **Mac Host (Assistant App)**: 
    - A lightweight menu bar application.
    - Receives text from the iPhone.
    - Uses macOS Accessibility APIs to inject the text into the currently active document/field.

## Capabilities

### New Capabilities
- **stt-transcriber**: Flutter integration with iOS `SFSpeechRecognizer` for real-time transcription.
- **remote-input-protocol**: A communication layer (using BLE or local network) to sync text chunks from phone to Mac.
- **mac-input-injector**: macOS utility to simulate keystrokes or use Accessibility payloads for text entry.

## Impact
- **Mobile**: Requires microphone and local network/Bluetooth permissions.
- **macOS**: Requires "Accessibility" permissions to allow the app to type on behalf of the user.
- **Workflow**: Drastically reduces the need for manual typing for long-form content.

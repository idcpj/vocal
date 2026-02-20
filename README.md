# Vocal - Remote Voice Keyboard

Turn your iPhone into a high-speed, low-latency voice input device for your Mac.

## 🚀 Quick Start

### 1. Mac Host (Swift)
The host application runs in your menu bar and receives text payloads via WebSocket, injecting them into the focused application.

**Compile and Run:**
```bash
# From the project root
swiftc -o VocalHost mac/VocalHostApp.swift -parse-as-library
./VocalHost &
```

**Permissions:**
- Click the **Mic Icon** in the menu bar.
- Select **Check Permissions**.
- If prompted, grant **Accessibility (辅助功能)** permission in `System Settings > Privacy & Security`.

### 2. iPhone Client (Flutter)
The client handles real-time speech recognition (using Apple's native STT engine) and streams results to the Mac.

**Run:**
```bash
cd mobile
flutter run
```

**Prerequisites:**
- Both devices must be on the **same Wi-Fi network**.
- Grant Microphone and Speech Recognition permissions when prompted on iOS.

## 🛠 Tech Stack
- **macOS**: Swift, Network.framework (WebSocket), mDNS (NetService), Accessibility APIs (AXUIElement).
- **iOS**: Flutter, SpeechToText (Native SFSpeechRecognizer), mDNS discovery.
- **Protocol**: Custom WebSocket streaming over TCP with mDNS discovery (`_vocal._tcp`).

## 🎨 Design Language
Follows the **Terminal × Minimal** aesthetic:
- **Dark Mode**: High-contrast slate and electric cyan.
- **Typography**: JetBrains Mono and Inter.
- **UI**: Single "Push to Talk" interaction with live transcription feedback.

## 📋 TODO
- [ ] mDNS 发现服务后，弹出列表供用户选择目标 Mac 名称（而非自动连接第一个）

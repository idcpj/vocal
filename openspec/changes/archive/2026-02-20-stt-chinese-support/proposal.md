## Why

The current implementation defaults to the system locale (which might be English) and doesn't explicitly handle switching to Chinese. Users need to speak Chinese and have it correctly transcribed, ideally with support for interleaved English words.

## What Changes

- **Locale Management**: Request available locales from the `speech_to_text` plugin.
- **Explicit Chinese Selection**: Allow the user to select or default to `zh-CN`, `zh-TW`, or `zh-HK`.
- **Bilingual Optimization**: Configure the STT engine session to optimize for Chinese and English recognition simultaneously where possible by passing relevant flags to the underlying iOS `SFSpeechRecognizer`.

## Capabilities

### Modified Capabilities
- `speech-recognition`: Adding multi-language support and locale-specific configuration.

## Impact

- **iPhone**: `mobile/lib/main.dart`

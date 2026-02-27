# Spec: Speech Recognition

## Requirements

- The system shall transcribe speech to text using the user's preferred locale.
- The system shall support continuous listening (dictation mode).
- The system shall automatically finalize a sentence after a period of silence (approx. 900ms).
- The system shall send the finalized sentence to the connected Mac host for injection.
- **Deduplication** (`speech-recognition.deduplication`): The system shall ensure that the same recognized string is not sent to the Mac host more than once per recognition event.

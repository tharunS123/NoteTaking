# Focus Notes

Focus Notes is a native SwiftUI note-taking app built for iOS 17 and above. The app captures spoken content, transcribes it using OpenRouter's `openai/gpt-4o-mini-transcribe` model, and then crafts production-quality study notes with `nvidia/nemotron-nano-9b-v2:free`.

## Features

- One-tap recording with automatic microphone permission handling.
- Secure upload of recordings to OpenRouter for transcription.
- Structured lecture-style notes distilled from the raw transcript.
- Modern SwiftUI interface that follows the latest Human Interface Guidelines.

## Requirements

- Xcode 16 or later (iOS 18 SDK) or Xcode 15 (iOS 17 SDK).
- An OpenRouter account with access to the `openai/gpt-4o-mini-transcribe` and `nvidia/nemotron-nano-9b-v2:free` models.

## Configuration

1. Create an OpenRouter API key.
2. In Xcode, open the **Build Settings** of the **NoteTaking** target.
3. Locate the user-defined setting `OPENROUTER_API_KEY` and set its value to your key. You can scope this setting per-configuration if desired.
4. The value is embedded into the generated `Info.plist` at runtime and accessed securely from code.

> **Tip:** Prefer storing your key in an `.xcconfig` file or in CI/CD secrets rather than committing it to source control.

## Running the App

1. Build and run the project on an iOS 17+ simulator or physical device.
2. Grant microphone permission when prompted.
3. Tap the record button to capture audio. Tap again to stop and trigger transcription.
4. Review the generated executive summary, key points, action items, and transcript.

## Privacy

- Recordings are stored temporarily in the app's caches directory and only uploaded while generating notes.
- The microphone permission string clearly explains why access is required.

## Deployment

The project targets modern deployment defaults and is ready for App Store distribution. Review Apple's submission guidelines to ensure your privacy policy covers audio uploads and third-party services.

# Reverse Wiki for Android

Native Android port built with Kotlin, Jetpack Compose and Material 3.

## Requirements

- Android Studio with JDK 17
- Android SDK 36
- Android 8.0 (API 26) or newer on the device
- At least one LLM API key configured from the app

## Local configuration

Copy `local.properties.example` to `local.properties`, then set the Android SDK path:

```properties
sdk.dir=/absolute/path/to/Android/sdk
```

The result map uses MapLibre with OpenFreeMap/OpenStreetMap data and does not require an API key.

`local.properties` and signing files are excluded from Git. LLM keys are entered in the app and
encrypted with Android Keystore; no LLM key is included in the APK or repository.

## Build

```bash
./gradlew assembleDebug
```

The debug APK is generated at `app/build/outputs/apk/debug/app-debug.apk`.

## Implemented MVP flow

- System camera and Android Photo Picker
- Optional device location and visual viewpoint inference
- Anthropic, Gemini, OpenAI, Kimi and OpenRouter clients
- Dynamic multimodal model catalog
- Provider/model/temperature configuration
- Encrypted API-key storage
- Cancelable analysis
- Local cache keyed by image, rounded GPS and model
- Search history with deletion
- Result image, cited text and MapLibre/OpenStreetMap map with uncertainty circle
- First-level help and source links

The Android project lives entirely under `android/`; the Xcode project remains unchanged.

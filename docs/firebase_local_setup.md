# Local Firebase and Android signing setup

This repository intentionally keeps some machine-local build files out of git.

## Files that stay local

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/key.properties`
- Any real keystore file such as `.jks` or `.keystore`

These files are ignored on purpose. Do not commit real Firebase config, signing credentials, or keystores.

## Android debug builds

Android debug builds do **not** require `android/key.properties`.

They still require valid local Firebase configuration when the app is built against real Firebase services:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

If you prefer to keep those files excluded from git, that is fine. Keep them local and document how teammates should obtain them.

## Android release builds

Android release builds require local signing configuration in `android/key.properties`.

1. Copy `android/key.properties.example` to `android/key.properties`
2. Fill in your local keystore path and passwords
3. Keep both the keystore and `android/key.properties` out of git

If you try to build release without `android/key.properties`, Gradle now fails with a clear message.

## Notes on secrets

`google-services.json` and `firebase_options.dart` do not always contain high-risk secrets by themselves, but they are still local environment files and should only be committed if your team explicitly decides to version them.

# FlagPost

FlagPost is a beta Android application focused on city-based local boards.

## Features

- **City Boards First**: Choose a city and read or leave practical tips, warnings, and notes from travelers and locals.
- **Optional Nearby & Chat**: You can use the Radar/Nearby feature if you wish to see people around you. This is completely optional and your exact location is never shared with other users.
- **Starter Prompts**: No fake users or fake messages. Empty boards come with intelligent editorial prompts to inspire the first useful notes.
- **Privacy First**: The app does not ask for GPS permissions during onboarding. You only share your location if you explicitly decide to use the Nearby feature.

## Project Status

This project is currently in beta and undergoing a pivot to focus primarily on local boards for travelers, expats, and compatriots.

## Local Build Setup

Some build files are intentionally kept local and excluded from git:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/key.properties`

Android debug builds do not require `android/key.properties`.

Android release builds do require local signing values in `android/key.properties`. Use [docs/firebase_local_setup.md](docs/firebase_local_setup.md) and start from [android/key.properties.example](android/key.properties.example).

# PackProof setup notes

## What was fixed in code
- Upload queue is now persisted with `shared_preferences`
- History screen now reads real saved videos from local storage
- Home screen now shows recent successful uploads
- Settings screen now shows real local storage usage instead of estimated values
- Recording flow now queues uploads without falsely marking them complete immediately
- Scanner service now uses the same order/tracking parser as the scanner UI

## One required manual step for iOS Google Sign-In
This project folder does not include an iOS `GoogleService-Info.plist` or a verified `REVERSED_CLIENT_ID` URL scheme.
Those values must come from your own Firebase / Google Cloud project for the iOS app bundle ID.

To finish iOS Google Sign-In:
1. Add the iOS app in Firebase for the correct bundle identifier.
2. Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
3. Add the `REVERSED_CLIENT_ID` from that plist into `ios/Runner/Info.plist` under `CFBundleURLTypes`.
4. Run `flutter pub get` and then build again.

Android Firebase config was already present in the project.

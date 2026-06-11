# Smart Daily Expense Manager_firebase

Flutter expense manager with direct Firebase backend.

## Tech stack
- Flutter 3+
- Provider (state management)
- Firebase Auth (Anonymous + Email/Password)
- Cloud Firestore (expenses/settings/tools storage)
- Firebase Crashlytics

## Data flow
- App reads/writes directly to Firestore.
- User data is stored per Firebase user UID under:
  - `users/{uid}/expenses/*`
  - `users/{uid}/meta/settings`
  - `users/{uid}/meta/tools`
  - `users/{uid}/meta/usage`
  - `users/{uid}/meta/subscription`

## Required packages (already in `pubspec.yaml`)
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_crashlytics`

## Firebase setup (Android + iOS + Web)
1. Install tools:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
2. From project root:
   ```bash
   flutterfire configure
   ```
   This generates correct `lib/firebase_options.dart` and platform config files.
3. In Firebase Console:
   - Enable `Authentication`:
     - `Email/Password`
     - `Anonymous`
   - Enable `Cloud Firestore` (production mode).
   - Enable `Crashlytics` (optional but recommended).
4. Firestore Security Rules (recommended start):
   ```txt
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
5. Get dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

## Important note about `firebase_options.dart`
- The file in this repo currently contains placeholders.
- Best path: run `flutterfire configure` to auto-generate real values.
- If you keep placeholders, Firebase calls will fail.

## Phone usage
- Works on Android/iOS once Firebase is configured for those platforms.
- For Android, ensure package name in Firebase matches your app `applicationId`.
- For iOS, ensure bundle id in Firebase matches Xcode bundle id.

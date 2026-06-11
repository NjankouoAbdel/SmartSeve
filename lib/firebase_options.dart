import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration generated manually.
/// Replace these placeholder values with your own project values
/// (or run `flutterfire configure` to regenerate this file automatically).
class DefaultFirebaseOptions {
  static bool get isConfiguredForCurrentPlatform {
    final FirebaseOptions options = currentPlatform;
    return _isConfigured(options);
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDKTVqgdSwLil6iBRwBLrTiglNe2-GxC2k',
    appId: '1:31035320301:web:128567c623ebb5c308e9e4',
    messagingSenderId: '31035320301',
    projectId: 'smartsave-c4344',
    authDomain: 'smartsave-c4344.firebaseapp.com',
    storageBucket: 'smartsave-c4344.firebasestorage.app',
    measurementId: 'G-T481SB8GCC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA4jIeTN3eX8W5uMZOHBZJZOkulglybIC0',
    appId: '1:31035320301:android:ac56458a32cf167a08e9e4',
    messagingSenderId: '31035320301',
    projectId: 'smartsave-c4344',
    storageBucket: 'smartsave-c4344.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'REPLACE_WITH_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: 'REPLACE_WITH_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'REPLACE_WITH_MACOS_BUNDLE_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WINDOWS_API_KEY',
    appId: 'REPLACE_WITH_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    authDomain: 'REPLACE_WITH_PROJECT_ID.firebaseapp.com',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.firebasestorage.app',
    measurementId: 'REPLACE_WITH_WINDOWS_MEASUREMENT_ID',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: 'REPLACE_WITH_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    authDomain: 'REPLACE_WITH_PROJECT_ID.firebaseapp.com',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.firebasestorage.app',
    measurementId: 'REPLACE_WITH_LINUX_MEASUREMENT_ID',
  );

  static bool _isConfigured(FirebaseOptions options) {
    bool hasValue(String? value) {
      if (value == null) {
        return false;
      }
      final String normalized = value.trim();
      return normalized.isNotEmpty && !normalized.startsWith('REPLACE_WITH_');
    }

    return hasValue(options.apiKey) &&
        hasValue(options.appId) &&
        hasValue(options.projectId) &&
        hasValue(options.messagingSenderId);
  }
}
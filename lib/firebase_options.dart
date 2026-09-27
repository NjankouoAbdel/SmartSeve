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
    apiKey: 'AIzaSyCWrjh9NhvQzKrF4OnoIT-94IFO74Xkb54',
    appId: '1:951914333528:web:bd4f92614426aa8a2c512d',
    messagingSenderId: '951914333528',
    projectId: 'smartsave-perso',
    authDomain: 'smartsave-perso.firebaseapp.com',
    storageBucket: 'smartsave-perso.firebasestorage.app',
    measurementId: 'G-MY2P7VN7HW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDT7DfFfWZe3r0Z8zuvi7jkg3MoA4iVMMs',
    appId: '1:951914333528:android:d663426e7e52e4d42c512d',
    messagingSenderId: '951914333528',
    projectId: 'smartsave-perso',
    storageBucket: 'smartsave-perso.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3jEJ_7RDVwt03sLf01FKyrA6CSXyBTYw',
    appId: '1:951914333528:ios:b5daf67137a56b062c512d',
    messagingSenderId: '951914333528',
    projectId: 'smartsave-perso',
    storageBucket: 'smartsave-perso.firebasestorage.app',
    iosBundleId: 'com.example.wferFlousk',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3jEJ_7RDVwt03sLf01FKyrA6CSXyBTYw',
    appId: '1:951914333528:ios:b5daf67137a56b062c512d',
    messagingSenderId: '951914333528',
    projectId: 'smartsave-perso',
    storageBucket: 'smartsave-perso.firebasestorage.app',
    iosBundleId: 'com.example.wferFlousk',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCWrjh9NhvQzKrF4OnoIT-94IFO74Xkb54',
    appId: '1:951914333528:web:c7efeaad64d51a2d2c512d',
    messagingSenderId: '951914333528',
    projectId: 'smartsave-perso',
    authDomain: 'smartsave-perso.firebaseapp.com',
    storageBucket: 'smartsave-perso.firebasestorage.app',
    measurementId: 'G-4ZBGDBXJ74',
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

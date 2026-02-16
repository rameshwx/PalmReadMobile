import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration for PalmRead.
///
/// Generated manually from the provided Firebase project settings.
/// If you later run `flutterfire configure`, you can replace this file.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for linux.',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA7s8VgRAu5yfx54lIyQ9cGdunQPmf1q44',
    appId: '1:713636760931:web:407f9b7c1a75fe6ff89756',
    messagingSenderId: '713636760931',
    projectId: 'palm-read-5cfa3',
    authDomain: 'palm-read-5cfa3.firebaseapp.com',
    storageBucket: 'palm-read-5cfa3.firebasestorage.app',
    measurementId: 'G-5VS7SPPH1S',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA7s8VgRAu5yfx54lIyQ9cGdunQPmf1q44',
    appId: '1:713636760931:web:407f9b7c1a75fe6ff89756',
    messagingSenderId: '713636760931',
    projectId: 'palm-read-5cfa3',
    storageBucket: 'palm-read-5cfa3.firebasestorage.app',
  );
}

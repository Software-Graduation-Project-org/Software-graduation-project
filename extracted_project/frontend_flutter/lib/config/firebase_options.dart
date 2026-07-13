import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
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
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:web:679b2deedc3fe8e8d25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    authDomain: 'medical-lab-6a8d4.firebaseapp.com',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:android:b0d486e0ad078eb1d25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:ios:32bc4de30c515850d25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
    iosBundleId: 'com.medicallab.frontendFlutter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:ios:32bc4de30c515850d25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:web:b2f56e6fc843608fd25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyBAWITb--SYYBTqXfZPeb8Maa7xH2eHuNk',
    appId: '1:617565931421:web:b2f56e6fc843608fd25174',
    messagingSenderId: '617565931421',
    projectId: 'medical-lab-6a8d4',
    storageBucket: 'medical-lab-6a8d4.firebasestorage.app',
  );
}

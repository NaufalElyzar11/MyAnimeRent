import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Generated/configured from the original project's google-services.json
class DefaultFirebaseOptions {
  static const String databaseUrl =
      'https://myanimerent-default-rtdb.asia-southeast1.firebasedatabase.app';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDy5y6fmGHwv0Gi4zpVBPzOIZNmuBXJ2JA',
    appId: '1:432957892640:android:7ad6bba4b76afbee737445',
    messagingSenderId: '432957892640',
    projectId: 'myanimerent',
    databaseURL: databaseUrl,
    storageBucket: 'myanimerent.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDy5y6fmGHwv0Gi4zpVBPzOIZNmuBXJ2JA',
    appId: '1:432957892640:android:7ad6bba4b76afbee737445',
    messagingSenderId: '432957892640',
    projectId: 'myanimerent',
    databaseURL: databaseUrl,
    storageBucket: 'myanimerent.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDy5y6fmGHwv0Gi4zpVBPzOIZNmuBXJ2JA',
    appId: '1:432957892640:android:7ad6bba4b76afbee737445',
    messagingSenderId: '432957892640',
    projectId: 'myanimerent',
    databaseURL: databaseUrl,
    storageBucket: 'myanimerent.firebasestorage.app',
  );
}

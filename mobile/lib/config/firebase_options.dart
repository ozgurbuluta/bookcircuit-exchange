// Firebase configuration for Flutter
// Generated from Firebase Console config

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBOeWd6_c_0ahGXvuiGQt2Wfd2GqMwArk0',
    appId: '1:620020407459:web:ee8bba26d0ee8596fe3316',
    messagingSenderId: '620020407459',
    projectId: 'turtle-turning-pages',
    authDomain: 'turtle-turning-pages.firebaseapp.com',
    storageBucket: 'turtle-turning-pages.firebasestorage.app',
    measurementId: 'G-2MP0V4D3XY',
  );

  // iOS configuration from GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUHisoTS48HNXZV08i5uBs3S5kPEPef8I',
    appId: '1:620020407459:ios:7a5d40ae2fca0e9dfe3316',
    messagingSenderId: '620020407459',
    projectId: 'turtle-turning-pages',
    storageBucket: 'turtle-turning-pages.firebasestorage.app',
    iosBundleId: 'com.turtleturningpages.turtleTurningPages',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBOeWd6_c_0ahGXvuiGQt2Wfd2GqMwArk0',
    appId: '1:620020407459:web:ee8bba26d0ee8596fe3316', // Replace with Android app ID
    messagingSenderId: '620020407459',
    projectId: 'turtle-turning-pages',
    storageBucket: 'turtle-turning-pages.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBOeWd6_c_0ahGXvuiGQt2Wfd2GqMwArk0',
    appId: '1:620020407459:web:ee8bba26d0ee8596fe3316',
    messagingSenderId: '620020407459',
    projectId: 'turtle-turning-pages',
    storageBucket: 'turtle-turning-pages.firebasestorage.app',
    iosBundleId: 'com.turtleturningpages.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBOeWd6_c_0ahGXvuiGQt2Wfd2GqMwArk0',
    appId: '1:620020407459:web:ee8bba26d0ee8596fe3316',
    messagingSenderId: '620020407459',
    projectId: 'turtle-turning-pages',
    authDomain: 'turtle-turning-pages.firebaseapp.com',
    storageBucket: 'turtle-turning-pages.firebasestorage.app',
    measurementId: 'G-2MP0V4D3XY',
  );
}

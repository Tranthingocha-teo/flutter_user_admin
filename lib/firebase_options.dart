// Cấu hình Firebase project "vku-product-admin-23itb"
// (lấy bằng lệnh: firebase apps:sdkconfig WEB / ANDROID)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Ứng dụng chỉ cấu hình Firebase cho Web và Android');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA9uSrueiKaP487LoavPB4l0agJlG2kSUE',
    appId: '1:448658765310:web:e45cff43470402d8d77caf',
    messagingSenderId: '448658765310',
    projectId: 'vku-product-admin-23itb',
    authDomain: 'vku-product-admin-23itb.firebaseapp.com',
    storageBucket: 'vku-product-admin-23itb.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhQh5syQt-2qggDDbcLCH1c0rHCXXNcS8',
    appId: '1:448658765310:android:e4015ffd9e5efe63d77caf',
    messagingSenderId: '448658765310',
    projectId: 'vku-product-admin-23itb',
    storageBucket: 'vku-product-admin-23itb.firebasestorage.app',
  );
}

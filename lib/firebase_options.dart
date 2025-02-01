import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDF4RUdaaHLItKMGdBbvoMCwZb7-HHR1bc',
      appId: '1:963126729998:android:5772c2b326cb1ba2f10b5f',
      messagingSenderId: '963126729998',
      projectId: 'kumblywifi',
      authDomain: 'kumblywifi.firebaseapp.com',
      storageBucket: 'kumblywifi.appspot.com',
    );
  }
}

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web config
      return const FirebaseOptions(
        apiKey: 'AIzaSyCPhYkRStD3mn1RbO2UIMw4TgV0rwwwLF0',
        authDomain: 'tabassum-marketplace-9821c.firebaseapp.com',
        projectId: 'tabassum-marketplace-9821c',
        storageBucket: 'tabassum-marketplace-9821c.firebasestorage.app',
        messagingSenderId: '236118694560',
        appId: '1:236118694560:web:f48ff1adb6f8d6e09247c5',
        measurementId: 'G-S4DCV6V39M',
      );
    }

    // Fallback for all other platforms (Android, iOS, etc.)
    return const FirebaseOptions(
      apiKey: 'AIzaSyCPhYkRStD3mn1RbO2UIMw4TgV0rwwwLF0',
      authDomain: 'tabassum-marketplace-9821c.firebaseapp.com',
      projectId: 'tabassum-marketplace-9821c',
      storageBucket: 'tabassum-marketplace-9821c.firebasestorage.app',
      messagingSenderId: '236118694560',
      appId: '1:236118694560:web:f48ff1adb6f8d6e09247c5',
      measurementId: 'G-S4DCV6V39M',
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase Initialized.');

    // Enable Firestore offline persistence (wrapped in try-catch for web compatibility)
    try {
      debugPrint('Configuring Firestore...');
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      debugPrint('Firestore Configured.');
    } catch (e) {
      debugPrint('Firestore Setting Error (Skipping): $e');
    }

    debugPrint('Starting App...');
    runApp(const ProviderScope(child: App()));
    debugPrint('runApp called.');
  } catch (e, stack) {
    debugPrint('CRITICAL APP START ERROR: $e');
    debugPrint('STACK TRACE: $stack');
    
    // Fallback UI in case of total failure
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText('App failed to start:\n$e'),
        ),
      ),
    ));
  }
}

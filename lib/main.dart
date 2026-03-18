import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/twa_service.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Telegram Web App as early as possible
  // so the loading screen is correctly shown inside Telegram
  try {
    final twa = TWAService();
    if (twa.isSupported) {
      twa.ready();   // Tell Telegram the app is ready (hides loading spinner)
      twa.expand();  // Request full-screen mode
    }
  } catch (e) {
    debugPrint('TWA early init error: $e');
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Enable Firestore offline persistence (web compatible)
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      debugPrint('Firestore Setting Error (Skipping): $e');
    }

    runApp(const ProviderScope(child: App()));
  } catch (e, stack) {
    debugPrint('CRITICAL APP START ERROR: $e');
    debugPrint('STACK TRACE: $stack');

    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText('App failed to start:\n$e'),
        ),
      ),
    ));
  }
}

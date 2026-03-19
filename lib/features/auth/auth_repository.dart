import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants.dart';
import '../../core/providers.dart';
import 'models/user_model.dart';

// ─── Bot backend URL ──────────────────────────────────────────────────────
// NOTE: Replace this with your actual Render URL
const _botBaseUrl = 'https://tabassum-bot.onrender.com';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firestoreProvider),
  );
});

class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore db;

  AuthRepository({required this.auth, required this.db});

  Stream<User?> authStateChanges() => auth.authStateChanges();

  /// Step 1: Check if user exists and login directly
  Future<bool> telegramLogin({required String telegramId}) async {
    final response = await http.post(
      Uri.parse('$_botBaseUrl/telegram-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telegramId': telegramId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Login xatolik yuz berdi');
    }

    if (data['needs_registration'] == true) {
      return true; // Needs registration
    }

    // Sign in with the Firebase Custom Token
    final token = data['token'] as String;
    await auth.signInWithCustomToken(token);
    return false; // Did not need registration, logged in successfully
  }

  /// Step 2: If user doesn't exist, register with extra fields
  Future<void> telegramRegister({
    required String telegramId,
    required String name,
    String surname = '',
    required int age,
  }) async {
    final response = await http.post(
      Uri.parse('$_botBaseUrl/telegram-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'telegramId': telegramId,
        'name': name,
        'surname': surname,
        'age': age,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Ro\'yxatdan o\'tishda xatolik yuz berdi');
    }

    // Sign in with the Firebase Custom Token
    final token = data['token'] as String;
    await auth.signInWithCustomToken(token);
  }

  Future<void> signOut() => auth.signOut();

  Future<UserModel?> fetchCurrentUserProfile() async {
    final u = auth.currentUser;
    if (u == null) return null;
    final snap = await db.collection(FirestoreCollections.users).doc(u.uid).get();
    final data = snap.data();
    if (data == null) return null;
    return UserModel.fromMap(snap.id, data);
  }

  Stream<UserModel?> watchCurrentUserProfile() {
    final u = auth.currentUser;
    if (u == null) return const Stream.empty();
    return db.collection(FirestoreCollections.users).doc(u.uid).snapshots().map((s) {
      final data = s.data();
      if (data == null) return null;
      return UserModel.fromMap(s.id, data);
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? phoneNumber,
    String? address,
  }) async {
    final Map<String, dynamic> data = {};
    if (displayName != null && displayName.isNotEmpty) data['displayName'] = displayName;
    if (phoneNumber != null && phoneNumber.isNotEmpty)  data['phoneNumber'] = phoneNumber;
    if (address != null && address.isNotEmpty)          data['address'] = address;

    if (data.isNotEmpty) {
      await db.collection(FirestoreCollections.users).doc(uid).update(data);
    }
  }

  Future<void> updateUserRole({required String uid, required UserRole role}) async {
    await db.collection(FirestoreCollections.users).doc(uid).update({'role': role.asString});
  }
}

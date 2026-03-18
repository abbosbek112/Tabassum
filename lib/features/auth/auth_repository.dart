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

  /// Step 1: Send OTP via Telegram bot
  Future<void> sendOtp({required String telegramId}) async {
    final response = await http.post(
      Uri.parse('$_botBaseUrl/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telegramId': telegramId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Kod yuborishda xatolik yuz berdi');
    }
  }

  /// Step 2: Verify OTP and sign in with Firebase Custom Token
  Future<void> verifyOtp({
    required String telegramId,
    required String code,
    required String name,
    String surname = '',
    required int age,
  }) async {
    final response = await http.post(
      Uri.parse('$_botBaseUrl/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'telegramId': telegramId,
        'code': code,
        'name': name,
        'surname': surname,
        'age': age,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Tasdiqlashda xatolik yuz berdi');
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

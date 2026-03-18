import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import 'models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required UserRole role,
    String phoneNumber = '',
  }) async {
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    final userDoc = db.collection(FirestoreCollections.users).doc(uid);
    final model = UserModel(
      uid: uid,
      email: email,
      role: role,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
    );
    await userDoc.set(model.toMap(), SetOptions(merge: true));

    return cred;
  }
  
  Future<UserCredential?> signInWithGoogle() async {
    late final UserCredential cred;

    if (kIsWeb) {
      // Web: use Firebase's built-in popup flow (no idToken issue)
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      cred = await auth.signInWithPopup(provider);
    } else {
      // Mobile: use google_sign_in package
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await auth.signInWithCredential(credential);
    }

    final user = cred.user;
    if (user != null) {
      // Create profile if it doesn't exist
      final userDoc = db.collection(FirestoreCollections.users).doc(user.uid);
      final snap = await userDoc.get();
      if (!snap.exists) {
        final model = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          role: UserRole.customer,
          createdAt: DateTime.now(),
        );
        await userDoc.set(model.toMap());
      }
    }

    return cred;
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
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
    // Fix #4: Whitelist — only these 3 fields are ever sent to Firestore.
    // This prevents accidental (or malicious) updates to role, email, createdAt.
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


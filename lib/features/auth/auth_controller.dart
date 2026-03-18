import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';
import 'auth_repository.dart';
import 'models/user_model.dart';

class AuthViewState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isUpdatingProfile;
  final UserModel? user;

  const AuthViewState({
    required this.isAuthenticated,
    required this.isLoading,
    this.isUpdatingProfile = false,
    this.user,
  });
}

final authStateProvider = StateProvider<AuthViewState>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  final userProfile = ref.watch(currentUserProfileProvider).value;
  
  return authAsync.when(
    data: (u) => AuthViewState(
      isAuthenticated: u != null, 
      isLoading: false,
      user: userProfile,
    ),
    error: (_, __) => const AuthViewState(isAuthenticated: false, isLoading: false),
    loading: () => const AuthViewState(isAuthenticated: false, isLoading: true),
  );
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authUserAsync = ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return authUserAsync.maybeWhen(
    data: (user) {
      if (user == null) return const Stream<UserModel?>.empty();
      return db
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .snapshots()
          .map((snap) => snap.data() == null ? null : UserModel.fromMap(snap.id, snap.data()!));
    },
    orElse: () => const Stream<UserModel?>.empty(),
  );
});

final routerRefreshNotifierProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  final Ref ref;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;

  _RouterRefreshNotifier(this.ref) {
    final auth = ref.read(firebaseAuthProvider);
    _authSub = auth.authStateChanges().listen((user) {
      notifyListeners();
      _profileSub?.cancel();
      
      if (user == null) return;
      
      _profileSub = ref
          .read(firestoreProvider)
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .snapshots()
          .listen((_) => notifyListeners());
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> sendOtp({required String telegramId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.sendOtp(telegramId: telegramId);
    });
  }

  Future<void> verifyOtp({
    required String telegramId,
    required String code,
    required String name,
    String surname = '',
    required int age,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.verifyOtp(
        telegramId: telegramId,
        code: code,
        name: name,
        surname: surname,
        age: age,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
    });
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? address,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final originalState = ref.read(authStateProvider);
    ref.read(authStateProvider.notifier).state = AuthViewState(
      isAuthenticated: originalState.isAuthenticated,
      isLoading: originalState.isLoading,
      isUpdatingProfile: true,
      user: originalState.user,
    );

    try {
      await _repo.updateProfile(
        uid: user.uid,
        displayName: displayName,
        phoneNumber: phoneNumber,
        address: address,
      );
    } finally {
      final currentState = ref.read(authStateProvider);
      ref.read(authStateProvider.notifier).state = AuthViewState(
        isAuthenticated: currentState.isAuthenticated,
        isLoading: currentState.isLoading,
        isUpdatingProfile: false,
        user: currentState.user,
      );
    }
  }
}

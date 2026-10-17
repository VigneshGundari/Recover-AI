import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthController extends AsyncNotifier<void> {
  late AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signInWithEmail(email, password));
    return !state.hasError;
  }

  Future<bool> signUp(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signUpWithEmail(email, password));
    return !state.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signOut());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

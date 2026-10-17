import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Developer toggle for biometrics during testing
final biometricEnabledProvider = StateProvider<bool>((ref) => false);

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(LocalAuthentication());
});

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService(this._auth);

  Future<bool> authenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      
      if (!canCheck || !isDeviceSupported) return true; // Bypass if unsupported
      
      return await _auth.authenticate(
        localizedReason: 'Secure your medical data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      // In a real app, track the error log.
      return false; // Fail secure
    }
  }
}

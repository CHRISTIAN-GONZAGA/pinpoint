import 'package:local_auth/local_auth.dart';

/// Biometric unlock for returning users.
class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> get canAuthenticate async {
    try {
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.canCheckBiometrics;
      return supported && enrolled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock PINPOINT with biometrics'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

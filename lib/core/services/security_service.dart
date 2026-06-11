import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService(this._localAuth);

  final LocalAuthentication _localAuth;

  bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return true;
  }

  Future<bool> canUseBiometrics() async {
    if (!isSupportedPlatform) {
      return false;
    }

    final bool canCheck = await _localAuth.canCheckBiometrics;
    final bool isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  Future<bool> authenticate() async {
    if (!isSupportedPlatform) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your expense data',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

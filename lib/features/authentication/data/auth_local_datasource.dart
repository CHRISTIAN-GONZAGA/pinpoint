import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for auth tokens and app preferences.
class AuthLocalDataSource {
  AuthLocalDataSource({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs;

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: accessToken);
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: AppConstants.tokenKey);

  Future<String?> getRefreshToken() => _secureStorage.read(key: AppConstants.refreshTokenKey);

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await _preferences;
    return prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete({required bool value}) async {
    final prefs = await _preferences;
    await prefs.setBool(AppConstants.onboardingCompleteKey, value);
  }

  Future<String?> getThemeMode() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.themeModeKey);
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.themeModeKey, mode);
  }

  Future<bool> isBiometricUnlockEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool(AppConstants.biometricUnlockKey) ?? false;
  }

  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(AppConstants.biometricUnlockKey, enabled);
  }

  Future<String?> getLastLoginEmail() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.lastLoginEmailKey);
  }

  Future<void> setLastLoginEmail(String email) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.lastLoginEmailKey, email);
  }

  Future<bool> hasStoredRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }
}

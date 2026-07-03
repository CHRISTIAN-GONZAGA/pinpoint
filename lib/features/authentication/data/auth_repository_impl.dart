import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/local_profile_service.dart';
import 'package:pinpoint/features/authentication/data/auth_local_datasource.dart';
import 'package:pinpoint/features/authentication/data/auth_remote_datasource.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository contract for authentication operations.
abstract interface class AuthRepository {
  Future<User> login({required String email, required String password, bool rememberMe});
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  });
  Future<User?> restoreSession();
  Future<User> continueAsGuest();
  Future<void> logout();
  Future<void> lockSession();
  Future<String?> requestPasswordReset(String email);
  Future<void> resetPassword({required String token, required String password});
  Future<void> deleteAccount();
  Future<bool> isOnboardingComplete();
  Future<void> completeOnboarding();
}

/// Authentication repository implementation.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required LocalProfileService localProfileService,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _localProfile = localProfileService;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final LocalProfileService _localProfile;

  @override
  Future<User> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) =>
      _remote.login(email: email, password: password, rememberMe: rememberMe);

  @override
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  }) =>
      _remote.register(
        fullName: fullName,
        email: email,
        password: password,
        mobileNumber: mobileNumber,
      );

  @override
  Future<User?> restoreSession() async {
    if (AppConstants.offlineFirstMode) {
      return _restoreLocalProfile();
    }
    final token = await _local.getAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      return await _remote.getProfile();
    } catch (_) {
      await _local.clearTokens();
      return null;
    }
  }

  Future<User?> _restoreLocalProfile() async {
    if (!await _localProfile.hasProfile()) return null;
    final name = await _localProfile.getName();
    if (name == null || name.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(AppConstants.languageKey) ?? 'en';
    final theme = prefs.getString(AppConstants.themeModeKey) ?? 'system';
    return User.localProfile(
      fullName: name,
      languagePreference: language,
      themePreference: theme,
    );
  }

  @override
  Future<User> continueAsGuest() async {
    if (AppConstants.offlineFirstMode) {
      final existing = await _restoreLocalProfile();
      if (existing != null) return existing;
      return User.guest();
    }
    return User.guest();
  }

  @override
  Future<void> logout() => _remote.logout();

  @override
  Future<void> lockSession() async {
    // Keeps refresh tokens for biometric unlock; no server call required.
  }

  @override
  Future<String?> requestPasswordReset(String email) =>
      _remote.requestPasswordReset(email);

  @override
  Future<void> resetPassword({required String token, required String password}) =>
      _remote.resetPassword(token: token, password: password);

  @override
  Future<void> deleteAccount() => _remote.deleteAccount();

  @override
  Future<bool> isOnboardingComplete() => _local.isOnboardingComplete();

  @override
  Future<void> completeOnboarding() => _local.setOnboardingComplete(value: true);
}

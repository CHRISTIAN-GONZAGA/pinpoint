import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/features/authentication/domain/auth_state.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';
/// Manages authentication state and session lifecycle.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      state = state.copyWith(
        user: user,
        isLoading: false,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            rememberMe: rememberMe,
          );
      state = state.copyWith(user: user, isLoading: false);
      if (rememberMe) {
        final local = ref.read(authLocalDataSourceProvider);
        await local.setLastLoginEmail(email);
        await local.setBiometricUnlockEnabled(true);
      }
      await _syncIfRegistered(user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).register(
            fullName: fullName,
            email: email,
            password: password,
            mobileNumber: mobileNumber,
          );
      state = state.copyWith(user: user, isLoading: false);
      await _syncIfRegistered(user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).continueAsGuest();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.isAuthenticated) {
        await ref.read(authRepositoryProvider).lockSession();
      }
      state = const AuthState(isInitialized: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
    }
  }

  Future<String?> requestPasswordReset(String email) async {
    state = state.copyWith(clearError: true);
    try {
      return await ref.read(authRepositoryProvider).requestPasswordReset(email);
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
      return null;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: token,
            password: password,
          );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      state = const AuthState(isInitialized: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final biometric = ref.read(biometricServiceProvider);
    final local = ref.read(authLocalDataSourceProvider);
    if (!await biometric.canAuthenticate) return false;
    if (!await local.hasStoredRefreshToken()) return false;

    final authenticated = await biometric.authenticate();
    if (!authenticated) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      state = state.copyWith(user: user, isLoading: false);
      await _syncIfRegistered(user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> isOnboardingComplete() =>
      ref.read(authRepositoryProvider).isOnboardingComplete();

  Future<void> completeOnboarding() =>
      ref.read(authRepositoryProvider).completeOnboarding();

  Future<bool> setupLocalProfile({
    required String name,
    required String languageCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(localProfileServiceProvider).saveProfile(
            name: name,
            languageCode: languageCode,
          );
      await ref.read(authRepositoryProvider).completeOnboarding();
      final user = User.localProfile(fullName: name.trim(), languagePreference: languageCode);
      state = state.copyWith(user: user, isLoading: false, isInitialized: true);
      await ref.read(accessibilityNotifierProvider.notifier).update(
            ref.read(accessibilityNotifierProvider).copyWith(languageCode: languageCode),
          );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(e),
      );
      return false;
    }
  }

  Future<void> resetLocalSession() async {
    await ref.read(localProfileServiceProvider).clearProfile();
    await ref.read(authLocalDataSourceProvider).setOnboardingComplete(value: false);
    state = const AuthState(isInitialized: true);
  }

  String _friendlyMessage(Object error) {
    final message = error.toString();
    if (message.contains('AppException:')) {
      return message.replaceFirst('AppException: ', '');
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _syncIfRegistered(User user) async {
    if (user.isGuest) return;
    try {
      final themeMode = ref.read(themeModeProvider);
      await ref.read(syncRepositoryProvider).syncForUser(
            themeMode: themeMode,
            languagePreference: user.languagePreference,
          );
    } catch (_) {}
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.admin;
});

final canUseBiometricUnlockProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(authLocalDataSourceProvider);
  final biometric = ref.watch(biometricServiceProvider);
  return await local.isBiometricUnlockEnabled() &&
      await local.hasStoredRefreshToken() &&
      await biometric.canAuthenticate;
});

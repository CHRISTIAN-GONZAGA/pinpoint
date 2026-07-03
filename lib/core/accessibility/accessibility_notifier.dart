import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/accessibility/accessibility_settings.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages accessibility and language preferences.
class AccessibilityNotifier extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() {
    Future.microtask(load);
    return const AccessibilitySettings();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AccessibilitySettings(
      largeText: prefs.getBool(AppConstants.largeTextKey) ?? false,
      reduceMotion: prefs.getBool(AppConstants.reduceMotionKey) ?? false,
      languageCode: prefs.getString(AppConstants.languageKey) ?? 'en',
      emergencyContactName: prefs.getString(AppConstants.emergencyContactNameKey),
      emergencyContactPhone: prefs.getString(AppConstants.emergencyContactPhoneKey),
    );
  }

  Future<void> update(AccessibilitySettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.largeTextKey, settings.largeText);
    await prefs.setBool(AppConstants.reduceMotionKey, settings.reduceMotion);
    await prefs.setString(AppConstants.languageKey, settings.languageCode);
    if (settings.emergencyContactName != null) {
      await prefs.setString(AppConstants.emergencyContactNameKey, settings.emergencyContactName!);
    }
    if (settings.emergencyContactPhone != null) {
      await prefs.setString(AppConstants.emergencyContactPhoneKey, settings.emergencyContactPhone!);
    }
    if (ref.read(isAuthenticatedProvider)) {
      try {
        await ref.read(userSettingsRepositoryProvider).updateProfile(settings.toSyncPayload());
      } catch (_) {}
    }
  }
}

final accessibilityNotifierProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(AccessibilityNotifier.new);

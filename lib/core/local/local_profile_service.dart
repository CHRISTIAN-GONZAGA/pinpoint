import 'package:pinpoint/app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local user profile stored on-device (no server login required).
class LocalProfileService {
  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.localProfileNameKey);
  }

  Future<void> saveProfile({required String name, String? languageCode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.localProfileNameKey, name.trim());
    if (languageCode != null) {
      await prefs.setString(AppConstants.languageKey, languageCode);
    }
  }

  Future<bool> hasProfile() async {
    final name = await getName();
    return name != null && name.trim().isNotEmpty;
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.localProfileNameKey);
  }
}

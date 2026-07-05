import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the preferred language for AI assistant replies.
class AiLanguageNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_load);
    return AiResponseLanguage.auto;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.aiResponseLanguageKey);
    if (saved != null && AiResponseLanguage.options.contains(saved)) {
      state = saved;
    }
  }

  Future<void> setLanguage(String code) async {
    if (!AiResponseLanguage.options.contains(code)) return;
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.aiResponseLanguageKey, code);
  }
}

final aiLanguageNotifierProvider =
    NotifierProvider<AiLanguageNotifier, String>(AiLanguageNotifier.new);

import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

import 'package:pinpoint/features/ai_chat/data/ai_intent_resolver.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';

/// Offline knowledge retrieval and template-based responses.
class AiLocalDataSource {
  Future<List<Map<String, dynamic>>> _documents() async {
    try {
      final box = await Hive.openBox(AppConstants.knowledgeCacheBoxName);
      final raw = box.get('documents');
      if (raw is List) {
        return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (_) {}
    return AssetLoader.loadJsonList(AssetPaths.knowledge, 'documents');
  }

  Future<AiChatResponse> chat({
    required String message,
    String? sessionId,
    double? latitude,
    double? longitude,
    String responseLanguage = AiResponseLanguage.auto,
  }) async {
    final docs = await _documents();
    final language = AiResponseLanguage.resolve(
      preference: responseLanguage,
      message: message,
    );

    final intentReply = await AiIntentResolver.tryResolve(
      message: message,
      language: language,
    );
    if (intentReply != null) {
      return AiChatResponse(
        response: intentReply,
        language: language,
        sessionId: sessionId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
        sources: const [],
        actions: const [],
        retrievalConfidence: 0.95,
      );
    }

    final normalized = message.toLowerCase();
    final matches = docs.where((doc) {
      final keywords = (doc['keywords'] as List<dynamic>? ?? []).cast<String>();
      return keywords.any(normalized.contains);
    }).toList();

    if (docs.isEmpty) {
      return AiChatResponse(
        response: _fallbackResponse(language),
        language: language,
        sessionId: sessionId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
        sources: const [],
        actions: const [],
        retrievalConfidence: 0,
      );
    }

    final selected = matches.isNotEmpty ? matches.first : docs.first;
    final response = _templateFor(selected, language);

    return AiChatResponse(
      response: response,
      language: language,
      sessionId: sessionId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      sources: [
        AiSource(
          title: selected['title'] as String? ?? 'PINPOINT Knowledge',
          category: selected['category'] as String? ?? 'general',
          score: matches.isEmpty ? 0.4 : 0.9,
          excerpt: response,
        ),
      ],
      actions: const [],
      retrievalConfidence: matches.isEmpty ? 0.4 : 0.9,
    );
  }

  Future<void> clearSession(String sessionId) async {
    // Local sessions are ephemeral; nothing to clear server-side.
  }

  String _fallbackResponse(String language) => switch (language) {
        'tl' =>
          'Maaari kitang tulungan sa transportasyon at turismo sa Butuan gamit ang lokal na datos ng PINPOINT.',
        'ceb' =>
          'Makatabang ko nimo sa transportasyon ug turismo sa Butuan gamit ang lokal nga datos sa PINPOINT.',
        _ =>
          'I can help with Butuan transport and tourism using PINPOINT local data. Try asking about jeepney routes, fares, or attractions.',
      };

  String _templateFor(Map<String, dynamic> doc, String language) {
    final key = switch (language) {
      'tl' => 'content_tl',
      'ceb' => 'content_ceb',
      _ => 'content_en',
    };
    return doc[key] as String? ?? doc['content_en'] as String? ?? 'I can help with Butuan transport and tourism.';
  }
}

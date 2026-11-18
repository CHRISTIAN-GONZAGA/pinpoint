import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

import 'package:pinpoint/features/ai_chat/data/ai_intent_resolver.dart';
import 'package:pinpoint/features/ai_chat/data/ai_keyword_responder.dart';
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
    } on Object catch (error) {
      debugPrint('PINPOINT cached knowledge unavailable: ${error.runtimeType}');
    }
    return AssetLoader.loadJsonList(AssetPaths.knowledge, 'documents');
  }

  Future<AiChatResponse> chat({
    required String message,
    String? sessionId,
    double? latitude,
    double? longitude,
    String responseLanguage = AiResponseLanguage.auto,
  }) async {
    final language = AiResponseLanguage.resolve(
      preference: responseLanguage,
      message: message,
    );

    String? intentReply;
    try {
      intentReply = await AiIntentResolver.tryResolve(
        message: message,
        language: language,
      );
    } on Object catch (error) {
      debugPrint(
        'PINPOINT local place lookup unavailable: ${error.runtimeType}',
      );
    }
    if (intentReply != null) {
      return _response(intentReply, language, sessionId, confidence: 0.95);
    }

    final keywordReply = AiKeywordResponder.respond(message, language);
    if (keywordReply != null) {
      return _response(
        keywordReply,
        language,
        sessionId,
        confidence: 0.85,
        sources: const [
          AiSource(
            title: 'PINPOINT offline guide',
            category: 'offline',
            score: 0.85,
            excerpt: 'Bundled keyword-based information',
          ),
        ],
      );
    }

    List<Map<String, dynamic>> docs;
    try {
      docs = await _documents();
    } on Object catch (error) {
      debugPrint('PINPOINT local knowledge unavailable: ${error.runtimeType}');
      return _response(
        AiKeywordResponder.unknown(language),
        language,
        sessionId,
      );
    }

    final normalized = message.toLowerCase();
    final matches = docs.where((doc) {
      final keywords = (doc['keywords'] as List<dynamic>? ?? []).cast<String>();
      return keywords.any(normalized.contains);
    }).toList();

    if (docs.isEmpty) {
      return _response(
        AiKeywordResponder.unknown(language),
        language,
        sessionId,
      );
    }

    if (matches.isEmpty) {
      return _response(
        AiKeywordResponder.unknown(language),
        language,
        sessionId,
      );
    }
    final selected = matches.first;
    final response = _templateFor(selected, language);

    return _response(
      response,
      language,
      sessionId,
      confidence: 0.9,
      sources: [
        AiSource(
          title: selected['title'] as String? ?? 'PINPOINT Knowledge',
          category: selected['category'] as String? ?? 'general',
          score: 0.9,
          excerpt: response,
        ),
      ],
    );
  }

  Future<void> clearSession(String sessionId) async {
    // Local sessions are ephemeral; nothing to clear server-side.
  }

  AiChatResponse _response(
    String response,
    String language,
    String? sessionId, {
    double confidence = 0,
    List<AiSource> sources = const [],
  }) {
    return AiChatResponse(
      response: AiKeywordResponder.markOffline(response, language),
      language: language,
      sessionId: sessionId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      sources: sources,
      actions: const [],
      retrievalConfidence: confidence,
    );
  }

  String _templateFor(Map<String, dynamic> doc, String language) {
    final key = switch (language) {
      'tl' => 'content_tl',
      'ceb' => 'content_ceb',
      _ => 'content_en',
    };
    return doc[key] as String? ?? doc['content_en'] as String? ?? 'I can help with Butuan transport and tourism.';
  }
}

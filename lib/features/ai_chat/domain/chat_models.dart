import 'package:equatable/equatable.dart';

/// A single chat message in the AI conversation.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    this.sources = const [],
    this.actions = const [],
    this.language,
    this.timestamp,
  });

  final String id;
  final String content;
  final bool isUser;
  final List<AiSource> sources;
  final List<AiAction> actions;
  final String? language;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [id, content, isUser, sources, actions, language];
}

/// Retrieved knowledge source shown with an assistant reply.
class AiSource extends Equatable {
  const AiSource({
    required this.title,
    required this.category,
    required this.score,
    required this.excerpt,
  });

  factory AiSource.fromJson(Map<String, dynamic> json) {
    return AiSource(
      title: json['title'] as String? ?? 'Knowledge',
      category: json['category'] as String? ?? 'general',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      excerpt: json['excerpt'] as String? ?? '',
    );
  }

  final String title;
  final String category;
  final double score;
  final String excerpt;

  @override
  List<Object?> get props => [title, category, score, excerpt];
}

/// Actionable item extracted from AI context (e.g. view on map).
class AiAction extends Equatable {
  const AiAction({
    required this.type,
    required this.label,
    this.latitude,
    this.longitude,
    this.placeType,
    this.placeId,
    this.routeCode,
  });

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: json['type'] as String? ?? 'view_on_map',
      label: json['label'] as String? ?? 'View on map',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeType: json['place_type'] as String?,
      placeId: (json['place_id'] as num?)?.toInt(),
      routeCode: json['route_code'] as String?,
    );
  }

  final String type;
  final String label;
  final double? latitude;
  final double? longitude;
  final String? placeType;
  final int? placeId;
  final String? routeCode;

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  List<Object?> get props => [type, label, latitude, longitude, placeType, placeId];
}

/// Response payload from the AI chat API.
class AiChatResponse extends Equatable {
  const AiChatResponse({
    required this.response,
    required this.language,
    required this.sessionId,
    required this.sources,
    required this.actions,
    required this.retrievalConfidence,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    final sourceList = json['sources'] as List<dynamic>? ?? [];
    final actionList = json['actions'] as List<dynamic>? ?? [];
    return AiChatResponse(
      response: json['response'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      sessionId: json['session_id'] as String? ?? '',
      sources: sourceList
          .map((e) => AiSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      actions: actionList
          .map((e) => AiAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      retrievalConfidence: (json['retrieval_confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  final String response;
  final String language;
  final String sessionId;
  final List<AiSource> sources;
  final List<AiAction> actions;
  final double retrievalConfidence;

  @override
  List<Object?> get props => [response, language, sessionId, sources, actions];
}

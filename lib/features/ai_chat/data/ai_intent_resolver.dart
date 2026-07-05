import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';

/// Handles greetings, place lookups, and simple queries for offline AI chat.
abstract final class AiIntentResolver {
  static Future<String?> tryResolve({
    required String message,
    required String language,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    if (_isGreeting(lower)) {
      return _greeting(language);
    }

    if (_isThanks(lower)) {
      return _thanks(language);
    }

    final place = await _matchPlace(lower);
    if (place != null) {
      return _placeAnswer(place, language);
    }

    if (_asksWhere(lower)) {
      final fuzzy = await _fuzzyPlaceSearch(lower);
      if (fuzzy != null) return _placeAnswer(fuzzy, language);
    }

    return null;
  }

  static bool _isGreeting(String lower) {
    return RegExp(
      r'^(hi|hello|hey|helo|kumusta|musta|maayong|good\s+(morning|afternoon|evening)|magandang)',
    ).hasMatch(lower);
  }

  static bool _isThanks(String lower) {
    return RegExp(r'^(thanks|thank you|salamat|salamat kaayo|ty)').hasMatch(lower);
  }

  static bool _asksWhere(String lower) {
    return RegExp(r'\b(where|saan|asa|location|nasa|find|locate)\b').hasMatch(lower);
  }

  static String _greeting(String language) => switch (language) {
        AiResponseLanguage.tagalog =>
          'Kumusta! Ako ang PINPOINT assistant mo para sa Butuan. '
              'Magtanong tungkol sa jeepney routes (R1–R7), pamasahe, Robinsons, SM, o tourist spots.',
        AiResponseLanguage.cebuano =>
          'Maayong adlaw! Ako ang imong PINPOINT assistant sa Butuan. '
              'Pangutana bahin sa jeepney routes (R1–R7), pletehan, Robinsons, SM, o tourist spots.',
        _ =>
          'Hello! I\'m your PINPOINT assistant for Butuan City. '
              'Ask me about jeepney routes (R1–R7), fares, malls like Robinsons or SM, or nearby places.',
      };

  static String _thanks(String language) => switch (language) {
        AiResponseLanguage.tagalog => 'Walang anuman! Safe travels sa Butuan.',
        AiResponseLanguage.cebuano => 'Way sapayan! Luwas nga biyahe sa Butuan.',
        _ => 'You\'re welcome! Safe travels in Butuan.',
      };

  static Future<Map<String, dynamic>?> _matchPlace(String lower) async {
    final places = await _places();
    for (final place in places) {
      final name = (place['name'] as String? ?? '').toLowerCase();
      final aliases = _aliasesFor(name);
      if (aliases.any(lower.contains)) return place;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fuzzyPlaceSearch(String lower) async {
    final places = await _places();
    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final place in places) {
      final name = (place['name'] as String? ?? '').toLowerCase();
      final tokens = name.split(RegExp(r'[\s,\-]+')).where((t) => t.length > 2);
      var score = 0;
      for (final token in tokens) {
        if (lower.contains(token)) score += token.length;
      }
      for (final alias in _aliasesFor(name)) {
        if (lower.contains(alias)) score += alias.length * 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = place;
      }
    }
    return bestScore >= 4 ? best : null;
  }

  static List<String> _aliasesFor(String name) {
    if (name.contains('robinson')) {
      return ['robinsons', 'robinson', 'rbp', 'robinsons place'];
    }
    if (name.contains('sm city')) {
      return ['sm', 'sm city', 'sm butuan'];
    }
    if (name.contains('7-eleven') || name.contains('7 eleven')) {
      return ['7-eleven', '7 eleven', '711', 'seven eleven'];
    }
    if (name.contains('city hall')) {
      return ['city hall', 'cityhall', 'munisipyo'];
    }
    if (name.contains('hospital')) {
      return ['hospital', 'ospital'];
    }
    return [name];
  }

  static String _placeAnswer(Map<String, dynamic> place, String language) {
    final name = place['name'] as String? ?? 'Place';
    final address = place['address'] as String? ?? 'Butuan City';
    final lat = place['latitude'];
    final lng = place['longitude'];
    final routeHint = _routeHint(name);

    final coords = lat != null && lng != null
        ? ' (${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)})'
        : '';

    return switch (language) {
      AiResponseLanguage.tagalog =>
        '$name ay matatagpuan sa $address$coords. $routeHint '
            'Gamitin ang Map tab para magplano ng ruta papunta doon.',
      AiResponseLanguage.cebuano =>
        'Ang $name naa sa $address$coords. $routeHint '
            'Gamita ang Map tab aron magplano og ruta padto.',
      _ =>
        '$name is located at $address$coords. $routeHint '
            'Use the Map tab to plan a route there.',
    };
  }

  static String _routeHint(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('robinson')) {
      return 'Jeepney route R2 serves Robinsons Place Butuan along J.C. Aquino Ave.';
    }
    if (lower.contains('sm city')) {
      return 'Jeepney route R3 serves SM City Butuan from downtown.';
    }
    if (lower.contains('city hall')) {
      return 'City Hall is in the downtown area — R7 and other routes pass nearby on Montilla Blvd.';
    }
    return 'Check LPTRP routes R1–R7 on the map for jeepney options.';
  }

  static Future<List<Map<String, dynamic>>> _places() async {
    final establishments =
        await AssetLoader.loadJsonList(AssetPaths.establishments, 'establishments');
    final attractions =
        await AssetLoader.loadJsonList(AssetPaths.attractions, 'attractions');
    return [...establishments, ...attractions];
  }
}

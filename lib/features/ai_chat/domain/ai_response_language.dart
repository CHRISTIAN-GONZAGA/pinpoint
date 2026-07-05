/// Supported AI assistant response languages.
abstract final class AiResponseLanguage {
  static const auto = 'auto';
  static const english = 'en';
  static const tagalog = 'tl';
  static const cebuano = 'ceb';

  static const options = [auto, english, tagalog, cebuano];

  static String label(String code) => switch (code) {
        auto => 'Auto (match your question)',
        english => 'English',
        tagalog => 'Tagalog',
        cebuano => 'Cebuano',
        _ => 'English',
      };

  static String shortLabel(String code) => switch (code) {
        auto => 'Auto',
        english => 'EN',
        tagalog => 'TL',
        cebuano => 'CEB',
        _ => code.toUpperCase(),
      };

  /// Resolves the language to use for a reply.
  static String resolve({
    required String preference,
    required String message,
  }) {
    if (preference != auto && options.contains(preference)) {
      return preference;
    }
    return detectFromMessage(message);
  }

  static String detectFromMessage(String message) {
    final lower = message.toLowerCase();
    if (RegExp(r'\b(asa|unsa|pila|kaayo|lami|padulong)\b').hasMatch(lower)) {
      return cebuano;
    }
    if (RegExp(r'\b(saan|magkano|jeep|ako|mga|po|paano|pamasahe)\b').hasMatch(lower)) {
      return tagalog;
    }
    return english;
  }

  static String welcomeMessage(String preference) {
    final lang = preference == auto ? english : preference;
    return switch (lang) {
      tagalog =>
        'Kumusta! Ako ang iyong PINPOINT transport assistant para sa Butuan City. '
            'Magtanong tungkol sa jeepney routes, pamasahe, tourist spots, o emergency contacts.',
      cebuano =>
        'Maayong adlaw! Ako ang imong PINPOINT transport assistant sa Butuan City. '
            'Pangutana bahin sa jeepney routes, pletehan, tourist spots, o emergency contacts.',
      _ =>
        'Hello! I\'m your PINPOINT transport assistant for Butuan City. '
            'Ask me about jeepney routes, fares, tourist spots, or emergency contacts.',
    };
  }
}

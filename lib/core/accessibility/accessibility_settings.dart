import 'package:equatable/equatable.dart';

/// Accessibility preferences stored locally and synced for registered users.
class AccessibilitySettings extends Equatable {
  const AccessibilitySettings({
    this.largeText = false,
    this.reduceMotion = false,
    this.languageCode = 'en',
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final bool largeText;
  final bool reduceMotion;
  final String languageCode;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  double get textScaleFactor => largeText ? 1.2 : 1.0;

  AccessibilitySettings copyWith({
    bool? largeText,
    bool? reduceMotion,
    String? languageCode,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return AccessibilitySettings(
      largeText: largeText ?? this.largeText,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      languageCode: languageCode ?? this.languageCode,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }

  Map<String, dynamic> toSyncPayload() => {
        'language_preference': languageCode,
        'large_text_enabled': largeText,
        'reduce_motion_enabled': reduceMotion,
        if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
        if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
      };

  factory AccessibilitySettings.fromProfile(Map<String, dynamic> json) {
    return AccessibilitySettings(
      largeText: json['large_text_enabled'] as bool? ?? false,
      reduceMotion: json['reduce_motion_enabled'] as bool? ?? false,
      languageCode: json['language_preference'] as String? ?? 'en',
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
    );
  }

  @override
  List<Object?> get props => [largeText, reduceMotion, languageCode];
}

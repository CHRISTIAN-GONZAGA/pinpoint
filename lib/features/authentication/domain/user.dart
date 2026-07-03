import 'package:equatable/equatable.dart';

/// User roles supported by PINPOINT.
enum UserRole {
  guest,
  user,
  admin;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.user,
    );
  }
}

/// Domain model representing an authenticated or guest user session.
class User extends Equatable {
  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.mobileNumber,
    this.languagePreference = 'en',
    this.themePreference = 'system',
    this.profilePhoto,
    this.createdAt,
    this.isGuest = false,
  });

  factory User.guest() => const User(
        id: 'guest',
        fullName: 'Guest',
        email: '',
        role: UserRole.guest,
        isGuest: true,
      );

  /// On-device profile used in offline-first mode (no server login).
  factory User.localProfile({
    required String fullName,
    String languagePreference = 'en',
    String themePreference = 'system',
  }) =>
      User(
        id: 'local',
        fullName: fullName,
        email: '',
        role: UserRole.user,
        languagePreference: languagePreference,
        themePreference: themePreference,
        isGuest: false,
      );

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'user'),
      mobileNumber: json['mobile_number'] as String?,
      languagePreference: json['language_preference'] as String? ?? 'en',
      themePreference: json['theme_preference'] as String? ?? 'system',
      profilePhoto: json['profile_photo'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isGuest: json['is_guest'] as bool? ?? false,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? mobileNumber;
  final String languagePreference;
  final String themePreference;
  final String? profilePhoto;
  final DateTime? createdAt;
  final bool isGuest;

  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'full_name': fullName,
        'email': email,
        'role': role.name,
        'mobile_number': mobileNumber,
        'language_preference': languagePreference,
        'theme_preference': themePreference,
        'profile_photo': profilePhoto,
        'created_at': createdAt?.toIso8601String(),
        'is_guest': isGuest,
      };

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    UserRole? role,
    String? mobileNumber,
    String? languagePreference,
    String? themePreference,
    String? profilePhoto,
    DateTime? createdAt,
    bool? isGuest,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      languagePreference: languagePreference ?? this.languagePreference,
      themePreference: themePreference ?? this.themePreference,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  @override
  List<Object?> get props => [id, email, role, isGuest];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

void main() {
  group('User', () {
    test('guest user has correct defaults', () {
      final guest = User.guest();
      expect(guest.isGuest, isTrue);
      expect(guest.role, UserRole.guest);
      expect(guest.fullName, 'Guest');
    });

    test('firstName extracts first word', () {
      const user = User(
        id: '1',
        fullName: 'Juan Dela Cruz',
        email: 'juan@example.com',
        role: UserRole.user,
      );
      expect(user.firstName, 'Juan');
    });

    test('local profile user is not a guest', () {
      final user = User.localProfile(fullName: 'Christian', languagePreference: 'en');
      expect(user.isGuest, isFalse);
      expect(user.id, 'local');
      expect(user.fullName, 'Christian');
    });

    test('fromJson parses user fields', () {
      final user = User.fromJson({
        'user_id': 42,
        'full_name': 'Maria Santos',
        'email': 'maria@example.com',
        'role': 'user',
      });
      expect(user.id, '42');
      expect(user.fullName, 'Maria Santos');
      expect(user.role, UserRole.user);
    });
  });
}

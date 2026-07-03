import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

void main() {
  test('guest user defaults', () {
    final guest = User.guest();
    expect(guest.isGuest, isTrue);
    expect(guest.role, UserRole.guest);
  });
}

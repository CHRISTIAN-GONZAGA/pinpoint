import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Time-of-day greetings for the home dashboard.
abstract final class GreetingUtils {
  static String timeGreeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String headline({User? user}) {
    final greeting = timeGreeting();
    if (user != null && !user.isGuest && user.fullName.trim().isNotEmpty) {
      return '$greeting, ${user.firstName}';
    }
    return greeting;
  }

  static String subtitle({User? user}) {
    if (user != null && user.isGuest) {
      return 'Discover ${AppConstants.cityName} — routes, places & AI help';
    }
    return 'Your guide to jeepneys, tricycles & places in ${AppConstants.cityName}';
  }
}

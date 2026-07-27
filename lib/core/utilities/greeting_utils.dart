import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Time-of-day greetings for the home dashboard.
abstract final class GreetingUtils {
  static String timeGreeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  static String? displayFirstName(User? user) {
    if (user == null || user.isGuest) return null;
    final raw = user.firstName.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'user' || lower == 'guest' || lower == 'admin') return null;
    // Capitalize cleanly for display.
    return raw[0].toUpperCase() + (raw.length > 1 ? raw.substring(1) : '');
  }

  static String headline({User? user, DateTime? now}) {
    final greeting = timeGreeting(now);
    final name = displayFirstName(user);
    if (name != null) return '$greeting, $name';
    return greeting;
  }

  static String subtitle({User? user, DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (user != null && user.isGuest) {
      return 'Explore ${AppConstants.cityName} — routes, places, and a local AI guide.';
    }
    if (hour < 12) {
      return 'Where are we heading in ${AppConstants.cityName} today?';
    }
    if (hour < 17) {
      return 'Ready when you are — jeepneys, tricycles, and places nearby.';
    }
    return 'Find a smooth ride home across ${AppConstants.cityName}.';
  }

  static String dateLine([DateTime? now]) {
    final value = now ?? DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[value.weekday - 1]} · ${months[value.month - 1]} ${value.day}';
  }

  static String initial({User? user}) {
    final name = displayFirstName(user);
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (user != null && user.isGuest) return 'G';
    return 'P';
  }
}

/// Lightweight localization for core PINPOINT UI strings.
abstract final class PinpointLocalizations {
  static const supportedLanguageCodes = ['en', 'tl', 'ceb'];

  static String t(String key, String languageCode) {
    final lang = supportedLanguageCodes.contains(languageCode) ? languageCode : 'en';
    return _strings[lang]?[key] ?? _strings['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'profile': 'Profile',
      'accessibility': 'Accessibility',
      'history': 'History',
      'favorites': 'Favorites',
      'sign_in': 'Sign In',
      'sign_out': 'Sign Out',
      'cached_routes': 'Saved Routes',
      'cached_routes_subtitle': 'Recently planned routes available offline',
      'delete_account': 'Delete Account',
      'delete_account_subtitle': 'Permanently remove your PINPOINT account',
      'forgot_password': 'Forgot Password?',
      'reset_password': 'Reset Password',
      'offline_notice': 'You are offline. Some features may be unavailable.',
    },
    'tl': {
      'profile': 'Profile',
      'accessibility': 'Accessibility',
      'history': 'Kasaysayan',
      'favorites': 'Mga Paborito',
      'sign_in': 'Mag-sign In',
      'sign_out': 'Mag-sign Out',
      'cached_routes': 'Mga Naka-save na Ruta',
      'cached_routes_subtitle': 'Mga kamakailang ruta na available offline',
      'delete_account': 'Burahin ang Account',
      'delete_account_subtitle': 'Permanenteng tanggalin ang iyong PINPOINT account',
      'forgot_password': 'Nakalimutan ang Password?',
      'reset_password': 'I-reset ang Password',
      'offline_notice': 'Offline ka. Maaaring hindi available ang ilang feature.',
    },
    'ceb': {
      'profile': 'Profile',
      'accessibility': 'Accessibility',
      'history': 'Kasaysayan',
      'favorites': 'Mga Paborito',
      'sign_in': 'Sign In',
      'sign_out': 'Sign Out',
      'cached_routes': 'Mga Na-save nga Ruta',
      'cached_routes_subtitle': 'Bag-ohay nga ruta nga available offline',
      'delete_account': 'Tangtanga ang Account',
      'delete_account_subtitle': 'Permanenteng tangtalon ang imong PINPOINT account',
      'forgot_password': 'Nakalimtan ang Password?',
      'reset_password': 'I-reset ang Password',
      'offline_notice': 'Offline ka. Ang uban nga feature mahimong dili available.',
    },
  };
}

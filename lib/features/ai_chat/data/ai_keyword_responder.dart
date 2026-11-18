import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';

/// Small, bundled answers for common questions when the AI service is offline.
abstract final class AiKeywordResponder {
  static String? respond(String message, String language) {
    final text = message.toLowerCase();
    final String? answer;
    if (_containsAny(text, [
      'emergency',
      '911',
      'police',
      'pulis',
      'fire',
      'sunog',
      'ambulance',
      'disaster',
      'emergency number',
      'hotline',
    ])) {
      answer = _emergency(language);
    } else if (_containsAny(text, [
      'weather',
      'schedule',
      'timetable',
      'arrival time',
      'live traffic',
      'real time',
      'operating hours',
      'open now',
    ])) {
      answer = _liveInformation(language);
    } else if (_containsAny(text, ['taxi', 'cab'])) {
      answer = _taxi(language);
    } else if (_containsAny(text, ['tricycle', 'trike', 'tuk-tuk', 'tuktuk'])) {
      answer = _tricycle(language);
    } else if (_containsAny(text, [
      'fare',
      'pamasahe',
      'pletye',
      'plete',
      'magkano',
      'how much',
      'bayad',
      'price',
    ])) {
      answer = _fares(language);
    } else if (_containsAny(text, [
      'tourist',
      'attraction',
      'museum',
      'park',
      'sightseeing',
      'tourism',
      'tourist spot',
      'pasalubong',
      'visit',
    ])) {
      answer = _tourism(language);
    } else if (_containsAny(text, [
          'route',
          'jeep',
          'jeepney',
          'puj',
          'lptrp',
          'asa ko mosakay',
          'which jeep',
        ]) ||
        RegExp(r'\br[1-7]\b').hasMatch(text)) {
      answer = _routes(text, language);
    } else if (_containsAny(text, [
      'airport',
      'bancasi',
      'paliparan',
      'eroplano',
    ])) {
      answer = _airport(language);
    } else if (_containsAny(text, [
      'how to use',
      'how do i use',
      'paano gamitin',
      'unsaon paggamit',
      'map tab',
      'plan a route',
      'plan route',
      'navigate',
      'directions',
      'direksyon',
      'destination',
    ])) {
      answer = _howToUse(language);
    } else if (_containsAny(text, [
      'robinsons',
      'robinson',
      'sm city',
      'mall',
      'integrated terminal',
      'bus terminal',
    ])) {
      answer = _destinations(text, language);
    } else if (_containsAny(text, [
      'account',
      'profile',
      'sign in',
      'sign up',
      'password',
      'login',
      'log in',
    ])) {
      answer = _account(language);
    } else if (_containsAny(text, [
      'what can you do',
      'what do you do',
      'help',
      'unsa imong',
      'ano ang kaya',
    ])) {
      answer = _help(language);
    } else {
      answer = null;
    }
    return answer == null ? null : _offlinePrefix(language) + answer;
  }

  static String unknown(String language) =>
      _offlinePrefix(language) +
      switch (language) {
        AiResponseLanguage.tagalog =>
          'Maaari pa rin akong tumulong gamit ang naka-save na impormasyon ng PINPOINT. '
              'Magtanong tungkol sa ruta ng jeep, pamasahe, tricycle, mga pasyalan, '
              'lokasyon, o emergency contacts sa Butuan. Para sa eksaktong biyahe, '
              'ilagay ang simula at destinasyon sa Map tab.',
        AiResponseLanguage.cebuano =>
          'Makatabang gihapon ko gamit ang naka-save nga impormasyon sa PINPOINT. '
              'Pangutana bahin sa jeepney route, plete, tricycle, tourist spots, '
              'lokasyon, o emergency contacts sa Butuan. Para sa tukmang biyahe, '
              'butangi og sinugdanan ug destinasyon sa Map tab.',
        _ =>
          'I can still help with PINPOINT’s saved information. Ask about jeepney '
              'routes, fares, tricycles, attractions, places, or emergency contacts '
              'in Butuan. For an exact trip, enter a start and destination in the Map tab.',
      };

  static String markOffline(String response, String language) {
    final prefix = _offlinePrefix(language);
    return response.startsWith(prefix) ? response : '$prefix$response';
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

  static String _offlinePrefix(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Hindi available ang AI ngayon. Sagot ng PINPOINT: ',
    AiResponseLanguage.cebuano =>
      'Dili available ang AI karon. Tubag sa PINPOINT: ',
    _ => 'AI is unavailable right now. PINPOINT quick answer: ',
  };

  static String _emergency(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Tumawag sa 911 para sa pulisya o sunog. Butuan Medical Center: '
          '(085) 342-0123; Caraga Regional Hospital: (085) 225-8001; '
          'Butuan City Disaster Risk Reduction: (085) 342-5600. Para sa agarang panganib, tumawag sa 911.',
    AiResponseLanguage.cebuano =>
      'Tawag sa 911 para sa pulis o sunog. Butuan Medical Center: '
          '(085) 342-0123; Caraga Regional Hospital: (085) 225-8001; '
          'Butuan City Disaster Risk Reduction: (085) 342-5600. Kung emerhensiya, tawag dayon sa 911.',
    _ =>
      'Call 911 for police or fire emergencies. Butuan Medical Center: '
          '(085) 342-0123; Caraga Regional Hospital: (085) 225-8001; '
          'Butuan City Disaster Risk Reduction: (085) 342-5600. For immediate danger, call 911.',
  };

  static String _fares(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Ayon sa naka-save na fare guide, PHP 13 ang minimum na pamasahe sa jeepney '
          'at PHP 1.80 bawat susunod na kilometro. Ang base fare ng tricycle ay '
          'PHP 15–25 depende sa zone. Nagbabago ang pamasahe; kumpirmahin sa operator.',
    AiResponseLanguage.cebuano =>
      'Sumala sa naka-save nga fare guide, PHP 13 ang minimum sa jeepney ug '
          'PHP 1.80 kada sunod nga kilometro. Ang base fare sa tricycle kay '
          'PHP 15–25 depende sa zone. Mahimong mausab ang plete; kumpirmaha sa operator.',
    _ =>
      'PINPOINT’s saved fare guide lists a PHP 13 jeepney minimum plus PHP 1.80 '
          'per succeeding kilometer, and PHP 15–25 tricycle base fares depending '
          'on the zone. Fares can change, so confirm with the operator.',
  };

  static String _tricycle(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Karaniwang ginagamit ang tricycle papunta sa pinakamalapit na jeepney stop '
          'kung malayo ang lakad. Ang base fare sa naka-save na guide ay PHP 15–25 '
          'depende sa zone. Itakda ang iyong biyahe sa Map tab para makita kung may tricycle leg.',
    AiResponseLanguage.cebuano =>
      'Kasagarang sakyan ang tricycle padulong sa duol nga jeepney stop kung layo ang lakaw. '
          'Ang base fare sa naka-save nga guide kay PHP 15–25 depende sa zone. '
          'I-set ang biyahe sa Map tab aron makita kung naay tricycle leg.',
    _ =>
      'A tricycle can connect you to a nearby jeepney stop when the walk is long. '
          'The saved guide lists PHP 15–25 base fares depending on the zone. '
          'Enter your trip in the Map tab to check whether a tricycle leg is available.',
  };

  static String _taxi(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Ayon sa naka-save na fare guide, PHP 40 ang taxi flag-down at PHP 13.50 '
          'bawat kilometro. Maaaring magbago ang singil; kumpirmahin sa operator.',
    AiResponseLanguage.cebuano =>
      'Sumala sa naka-save nga fare guide, PHP 40 ang taxi flag-down ug PHP 13.50 '
          'kada kilometro. Mahimong mausab ang bayad; kumpirmaha sa operator.',
    _ =>
      'PINPOINT’s saved fare guide lists a PHP 40 taxi flag-down rate plus PHP 13.50 '
          'per kilometer. Rates can change; confirm with the operator.',
  };

  static String _tourism(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Kabilang sa mga pasyalan sa naka-save na PINPOINT guide ang Balangay Shrine '
          'Museum, Butuan National Museum, Guingona Park, at Delta Discovery Park. '
          'Gamitin ang Explore tab para tingnan ang mga lugar at ang Map tab para magplano.',
    AiResponseLanguage.cebuano =>
      'Apil sa mga pasyalan sa naka-save nga PINPOINT guide ang Balangay Shrine '
          'Museum, Butuan National Museum, Guingona Park, ug Delta Discovery Park. '
          'Gamita ang Explore tab sa pagtan-aw sa mga lugar ug Map tab sa pagplano.',
    _ =>
      'PINPOINT’s saved guide includes Balangay Shrine Museum, Butuan National Museum, '
          'Guingona Park, and Delta Discovery Park. Use Explore to browse places and '
          'Map to plan a trip.',
  };

  static String _routes(String text, String language) {
    final route = RegExp(
      r'\br([1-7])\b',
    ).firstMatch(text)?.group(0)?.toUpperCase();
    if (route != null) {
      final names = const {
        'R1': 'West and East Loop',
        'R2': 'City Proper Loop via Bancasi Airport',
        'R3': 'Ampayon to Libertad',
        'R4': 'De Oro',
        'R5': 'Santo Niño',
        'R6': 'Maguinda',
        'R7': 'Tungao',
      };
      final name = names[route]!;
      return _routeDetail(route, name, language);
    }
    return switch (language) {
      AiResponseLanguage.tagalog =>
        'Gumagamit ang PINPOINT ng LPTRP 2024 routes: R1 West and East Loop, '
            'R2 City Proper Loop via Bancasi Airport, R3 Ampayon–Libertad, '
            'R4 De Oro, R5 Santo Niño, R6 Maguinda, at R7 Tungao. '
            'Ilagay ang simula at destinasyon sa Map tab para makita ang mga opsyon. '
            'Maaaring kailanganin ang tricycle kung walang jeepney stop malapit.',
      AiResponseLanguage.cebuano =>
        'Gigamit sa PINPOINT ang LPTRP 2024 routes: R1 West and East Loop, '
            'R2 City Proper Loop via Bancasi Airport, R3 Ampayon–Libertad, '
            'R4 De Oro, R5 Santo Niño, R6 Maguinda, ug R7 Tungao. '
            'Ibutang ang sinugdanan ug destinasyon sa Map tab aron makita ang opsyon. '
            'Tingali kinahanglan og tricycle kung walay duol nga jeepney stop.',
      _ =>
        'PINPOINT’s saved LPTRP 2024 guide lists R1 West and East Loop, R2 City '
            'Proper Loop via Bancasi Airport, R3 Ampayon–Libertad, R4 De Oro, '
            'R5 Santo Niño, R6 Maguinda, and R7 Tungao. Enter your start and '
            'destination in the Map tab to compare options. A tricycle may be needed '
            'if no jeepney stop is nearby.',
    };
  }

  static String _routeDetail(
    String route,
    String name,
    String language,
  ) => switch (language) {
    AiResponseLanguage.tagalog =>
      '$route sa naka-save na LPTRP 2024 guide ay $name. Tingnan ang buong '
          'linya at mga stop nito sa Map tab; maaaring may pagbabago sa aktuwal na serbisyo.',
    AiResponseLanguage.cebuano =>
      '$route sa naka-save nga LPTRP 2024 guide kay $name. Tan-awa ang tibuok '
          'linya ug mga stop niini sa Map tab; mahimong mausab ang aktuwal nga serbisyo.',
    _ =>
      '$route is listed in PINPOINT’s saved LPTRP 2024 guide as $name. '
          'Check its full line and stops in the Map tab; actual service may change.',
  };

  static String _airport(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Ang Bancasi Airport ay kasama sa City Proper Loop ng R2 ayon sa naka-save '
          'na LPTRP guide. Ilagay ang iyong pinanggalingan at Bancasi Airport sa Map tab '
          'para makita ang mga opsyon.',
    AiResponseLanguage.cebuano =>
      'Ang Bancasi Airport apil sa City Proper Loop sa R2 sumala sa naka-save nga '
          'LPTRP guide. Ibutang ang sinugdanan ug Bancasi Airport sa Map tab aron makita ang opsyon.',
    _ =>
      'PINPOINT’s saved LPTRP guide lists Bancasi Airport on the R2 City Proper Loop. '
          'Enter your starting point and Bancasi Airport in the Map tab to see trip options.',
  };

  static String _destinations(String text, String language) {
    if (text.contains('robinson')) {
      return switch (language) {
        AiResponseLanguage.tagalog =>
          'Ang Robinsons Place Butuan ay nasa J.C. Aquino Ave, Brgy. Bayanihan. '
              'Ayon sa naka-save na guide, dumaraan doon ang R2. Gamitin ang Map tab '
              'para ikumpara ang ruta mula sa iyong lokasyon.',
        AiResponseLanguage.cebuano =>
          'Ang Robinsons Place Butuan naa sa J.C. Aquino Ave, Brgy. Bayanihan. '
              'Sumala sa naka-save nga guide, moagi didto ang R2. Gamita ang Map tab '
              'aron itandi ang ruta gikan sa imong lokasyon.',
        _ =>
          'Robinsons Place Butuan is on J.C. Aquino Ave, Brgy. Bayanihan. '
              'PINPOINT’s saved guide lists R2 as serving it. Use the Map tab to '
              'compare a route from your location.',
      };
    }
    if (text.contains('sm')) {
      return switch (language) {
        AiResponseLanguage.tagalog =>
          'Ang SM City Butuan ay nasa J.C. Aquino Ave, Brgy. Lapu-Lapu. '
              'Nakalista sa naka-save na guide ang R3. Gamitin ang Map tab para '
              'ikumpirma ang pinakamainam na ruta mula sa iyong lokasyon.',
        AiResponseLanguage.cebuano =>
          'Ang SM City Butuan naa sa J.C. Aquino Ave, Brgy. Lapu-Lapu. '
              'Nakalista sa naka-save nga guide ang R3. Gamita ang Map tab aron '
              'makumpirma ang pinakamaayong ruta gikan sa imong lokasyon.',
        _ =>
          'SM City Butuan is on J.C. Aquino Ave, Brgy. Lapu-Lapu. The saved guide '
              'lists R3; use the Map tab to confirm the best route from your location.',
      };
    }
    return switch (language) {
      AiResponseLanguage.tagalog =>
        'Ang Integrated Terminal sa J.C. Aquino ay pangunahing hub para sa R1, R2, '
            'at mga transfer ayon sa naka-save na guide. Ilagay ito bilang destinasyon '
            'sa Map tab para makita ang mga ruta.',
      AiResponseLanguage.cebuano =>
        'Ang Integrated Terminal sa J.C. Aquino usa ka major hub sa R1, R2, ug mga '
            'transfer sumala sa naka-save nga guide. Ibutang kini nga destinasyon sa '
            'Map tab aron makita ang mga ruta.',
      _ =>
        'The J.C. Aquino Integrated Terminal is a major hub for R1, R2, and transfers '
            'in PINPOINT’s saved guide. Set it as your destination in the Map tab to see routes.',
    };
  }

  static String _howToUse(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Buksan ang Map tab, piliin o ilagay ang simula at destinasyon, at pindutin '
          'ang pagbuo ng ruta. Ipapakita ng PINPOINT ang mga opsyon at uri ng sasakyan. '
          'Gamitin ang Explore tab para maghanap ng mga lugar.',
    AiResponseLanguage.cebuano =>
      'Ablihi ang Map tab, pilia o ibutang ang sinugdanan ug destinasyon, unya '
          'pindota ang paghimo og ruta. Ipakita sa PINPOINT ang mga opsyon ug sakyanan. '
          'Gamita ang Explore tab sa pagpangita og mga lugar.',
    _ =>
      'Open the Map tab, choose or enter a start and destination, then generate a route. '
          'PINPOINT will show available options and transport modes. Use Explore to browse places.',
  };

  static String _liveInformation(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Walang live na weather, schedule, arrival-time, traffic, o opening-hours feed '
          'sa naka-save na PINPOINT data. Tingnan ang Map o Explore tab para sa impormasyong '
          'available sa app at kumpirmahin ang kasalukuyang serbisyo sa operator.',
    AiResponseLanguage.cebuano =>
      'Walay live nga weather, schedule, arrival-time, traffic, o opening-hours feed '
          'sa naka-save nga PINPOINT data. Tan-awa ang Map o Explore tab sa impormasyong '
          'anaa sa app ug kumpirmaha ang serbisyo sa operator.',
    _ =>
      'PINPOINT’s saved data does not include live weather, schedules, arrival times, '
          'traffic, or opening hours. Check the Map or Explore tabs for available app '
          'information and confirm current service with the operator.',
  };

  static String _account(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Buksan ang Profile tab para sa account at mga setting. Kung hindi ka makapag-sign '
          'in o nakalimutan ang password, gamitin ang opsyong nasa sign-in screen.',
    AiResponseLanguage.cebuano =>
      'Ablihi ang Profile tab para sa account ug settings. Kung dili ka maka-sign in '
          'o nakalimot sa password, gamita ang opsyon sa sign-in screen.',
    _ =>
      'Open the Profile tab for account and settings options. If you cannot sign in or '
          'forgot your password, use the option on the sign-in screen.',
  };

  static String _help(String language) => switch (language) {
    AiResponseLanguage.tagalog =>
      'Makakatulong ako sa mga naka-save na impormasyon tungkol sa jeepney routes, '
          'pamasahe, tricycle, mga pasyalan, lokasyon, at emergency contacts sa Butuan. '
          'Para sa eksaktong biyahe, gamitin ang Map tab.',
    AiResponseLanguage.cebuano =>
      'Makatabang ko sa naka-save nga impormasyon bahin sa jeepney routes, plete, '
          'tricycle, tourist spots, lokasyon, ug emergency contacts sa Butuan. '
          'Para sa tukmang biyahe, gamita ang Map tab.',
    _ =>
      'I can answer using saved information about jeepney routes, fares, tricycles, '
          'attractions, places, and emergency contacts in Butuan. Use the Map tab for an exact trip.',
  };
}

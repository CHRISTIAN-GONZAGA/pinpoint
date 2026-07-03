/// LPTRP unserved-road policy message when no jeepney option is viable.
const unservedJeepneyMessage =
    'No verified LPTRP jeepney corridor fully serves this trip. '
    'The official map notes not every road is depicted — tricycle or walking may be required.';

/// User preference for how routes are scored and ranked.
enum RoutePreference {
  balanced,
  cheapest,
  fastest,
  leastWalking,
  fewestTransfers,
}

/// Badge labels assigned to route options after ranking.
enum RouteLabel {
  recommended,
  cheapest,
  fastest,
  leastWalking,
  fewestTransfers,
}

/// Configurable weights for route scoring (must sum to 1.0).
class ScoringWeights {
  const ScoringWeights({
    required this.walkingDistance,
    required this.travelTime,
    required this.fare,
    required this.transfers,
    this.taxiPenalty = 0,
  });

  final double walkingDistance;
  final double travelTime;
  final double fare;
  final double transfers;
  final double taxiPenalty;

  static ScoringWeights forPreference(RoutePreference preference) => switch (preference) {
        RoutePreference.cheapest => const ScoringWeights(
              walkingDistance: 0.15,
              travelTime: 0.15,
              fare: 0.55,
              transfers: 0.15,
            ),
        RoutePreference.fastest => const ScoringWeights(
              walkingDistance: 0.10,
              travelTime: 0.60,
              fare: 0.15,
              transfers: 0.15,
            ),
        RoutePreference.leastWalking => const ScoringWeights(
              walkingDistance: 0.55,
              travelTime: 0.20,
              fare: 0.10,
              transfers: 0.15,
            ),
        RoutePreference.fewestTransfers => const ScoringWeights(
              walkingDistance: 0.20,
              travelTime: 0.25,
              fare: 0.15,
              transfers: 0.40,
            ),
        RoutePreference.balanced => const ScoringWeights(
              walkingDistance: 0.40,
              travelTime: 0.30,
              fare: 0.20,
              transfers: 0.10,
              taxiPenalty: 35,
            ),
      };

  String get explanation => switch (this) {
        ScoringWeights(walkingDistance: >= 0.5) => 'Prioritizes less walking.',
        ScoringWeights(travelTime: >= 0.5) => 'Prioritizes fastest arrival.',
        ScoringWeights(fare: >= 0.5) => 'Prioritizes lowest fare.',
        ScoringWeights(transfers: >= 0.35) => 'Prioritizes fewer transfers.',
        _ => 'Balances walking, time, fare, and transfers.',
      };
}

extension RouteLabelDisplay on RouteLabel {
  String get title => switch (this) {
        RouteLabel.recommended => 'Recommended',
        RouteLabel.cheapest => 'Cheapest',
        RouteLabel.fastest => 'Fastest',
        RouteLabel.leastWalking => 'Least walking',
        RouteLabel.fewestTransfers => 'Fewest transfers',
      };

  String get explanation => switch (this) {
        RouteLabel.recommended =>
          'Best balance of travel time, fare, and walking for public transport.',
        RouteLabel.cheapest => 'Lowest estimated fare.',
        RouteLabel.fastest => 'Fastest estimated arrival.',
        RouteLabel.leastWalking => 'Shortest total walking distance.',
        RouteLabel.fewestTransfers => 'Fewest vehicle changes.',
      };
}

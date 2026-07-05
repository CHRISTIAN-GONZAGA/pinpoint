import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/route_scorer.dart';

/// Ranks candidates, assigns labels, and picks the recommended option.
class RouteRanker {
  const RouteRanker({RouteScorer? scorer}) : _scorer = scorer ?? const RouteScorer();

  final RouteScorer _scorer;

  List<PlannedRoute> rank({
    required List<PlannedRoute> candidates,
    required RoutePreference preference,
    VehicleMode preferredMode = VehicleMode.auto,
  }) {
    if (candidates.isEmpty) return [];

    final weights = ScoringWeights.forPreference(preference);
    final maxWalking = candidates
        .map((c) => c.walkingDistanceMeters)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final maxDuration = candidates
        .map((c) => c.totalDurationSeconds.toDouble())
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final maxFare = candidates
        .map((c) => c.estimatedFare)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final maxTransfers = candidates
        .map((c) => c.transferCount)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 999);

    final scored = candidates.map((route) {
      final score = _scorer.score(
        route,
        weights,
        maxWalking: maxWalking,
        maxDuration: maxDuration,
        maxFare: maxFare,
        maxTransfers: maxTransfers,
      );
      return route.copyWith(rankScore: score);
    }).toList();

    scored.sort((a, b) => (a.rankScore ?? 0).compareTo(b.rankScore ?? 0));

    final publicTransport = scored
        .where((r) =>
            r.primaryMode == VehicleMode.jeepney ||
            r.primaryMode == VehicleMode.walk ||
            r.primaryMode == VehicleMode.tricycle)
        .toList();

    var recommendedIdx = 0;
    if (preferredMode != VehicleMode.auto) {
      final matchIdx = scored.indexWhere((r) => r.primaryMode == preferredMode);
      if (matchIdx >= 0) recommendedIdx = matchIdx;
    } else {
      final jeepneyOptions =
          scored.where((r) => r.primaryMode == VehicleMode.jeepney).toList();
      final walkOption =
          scored.where((r) => r.primaryMode == VehicleMode.walk).firstOrNull;

      if (jeepneyOptions.isNotEmpty) {
        final shortWalk = walkOption != null &&
            walkOption.walkingDistanceMeters < 600 &&
            walkOption.totalDistanceMeters < 900;
        recommendedIdx = shortWalk
            ? scored.indexOf(walkOption)
            : scored.indexOf(jeepneyOptions.first);
      } else if (publicTransport.isNotEmpty) {
        recommendedIdx = scored.indexOf(publicTransport.first);
      }
    }

    final cheapest = _bestBy(scored, (r) => r.estimatedFare);
    final fastest = _bestBy(scored, (r) => r.totalDurationSeconds.toDouble());
    final leastWalking = _bestBy(scored, (r) => r.walkingDistanceMeters);
    final fewestTransfers = _bestBy(scored, (r) => r.transferCount.toDouble());

    return scored.asMap().entries.map((entry) {
      final idx = entry.key;
      final route = entry.value;
      final labels = <RouteLabel>[];

      if (idx == recommendedIdx) labels.add(RouteLabel.recommended);
      if (route.optionId == cheapest?.optionId) labels.add(RouteLabel.cheapest);
      if (route.optionId == fastest?.optionId) labels.add(RouteLabel.fastest);
      if (route.optionId == leastWalking?.optionId) labels.add(RouteLabel.leastWalking);
      if (route.optionId == fewestTransfers?.optionId) labels.add(RouteLabel.fewestTransfers);

      final explanation = _explanationFor(route, labels, preference);

      return route.copyWith(
        isRecommended: labels.contains(RouteLabel.recommended),
        explanation: explanation,
      );
    }).toList();
  }

  PlannedRoute? _bestBy(
    List<PlannedRoute> routes,
    double Function(PlannedRoute) metric,
  ) {
    if (routes.isEmpty) return null;
    return routes.reduce((a, b) => metric(a) <= metric(b) ? a : b);
  }

  String _explanationFor(
    PlannedRoute route,
    List<RouteLabel> labels,
    RoutePreference preference,
  ) {
    if (labels.contains(RouteLabel.recommended)) {
      return RouteLabel.recommended.explanation;
    }
    if (labels.contains(RouteLabel.cheapest)) return RouteLabel.cheapest.explanation;
    if (labels.contains(RouteLabel.fastest)) return RouteLabel.fastest.explanation;
    if (labels.contains(RouteLabel.leastWalking)) return RouteLabel.leastWalking.explanation;
    if (labels.contains(RouteLabel.fewestTransfers)) {
      return RouteLabel.fewestTransfers.explanation;
    }
    return ScoringWeights.forPreference(preference).explanation;
  }
}

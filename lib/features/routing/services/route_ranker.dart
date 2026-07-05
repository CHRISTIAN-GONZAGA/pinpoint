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

    final cheapest = _bestBy(scored, (r) => r.estimatedFare);
    final fastest = _bestBy(scored, (r) => r.totalDurationSeconds.toDouble());
    final leastWalking = _bestBy(scored, (r) => r.walkingDistanceMeters);
    final fewestTransfers = _bestBy(scored, (r) => r.transferCount.toDouble());

    final recommendedIdx = _pickRecommendedIndex(
      scored: scored,
      preference: preference,
      preferredMode: preferredMode,
      cheapest: cheapest,
      fastest: fastest,
      leastWalking: leastWalking,
      fewestTransfers: fewestTransfers,
    );

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

  int _pickRecommendedIndex({
    required List<PlannedRoute> scored,
    required RoutePreference preference,
    required VehicleMode preferredMode,
    required PlannedRoute? cheapest,
    required PlannedRoute? fastest,
    required PlannedRoute? leastWalking,
    required PlannedRoute? fewestTransfers,
  }) {
    if (scored.isEmpty) return 0;

    if (preferredMode != VehicleMode.auto) {
      final matchIdx = scored.indexWhere((r) => r.primaryMode == preferredMode);
      if (matchIdx >= 0) return matchIdx;
    }

    switch (preference) {
      case RoutePreference.cheapest:
        return _indexOf(scored, cheapest);
      case RoutePreference.fastest:
        return _indexOf(scored, fastest);
      case RoutePreference.leastWalking:
        return _indexOf(scored, leastWalking);
      case RoutePreference.fewestTransfers:
        return _indexOf(scored, fewestTransfers);
      case RoutePreference.balanced:
        return _balancedRecommendation(scored);
    }
  }

  int _indexOf(List<PlannedRoute> scored, PlannedRoute? target) {
    if (target == null) return 0;
    final idx = scored.indexWhere((r) => r.optionId == target.optionId);
    return idx >= 0 ? idx : 0;
  }

  int _balancedRecommendation(List<PlannedRoute> scored) {
    final publicTransport = scored
        .where((r) =>
            r.primaryMode == VehicleMode.jeepney ||
            r.primaryMode == VehicleMode.walk ||
            r.primaryMode == VehicleMode.tricycle)
        .toList();

    final jeepneyOptions =
        scored.where((r) => r.primaryMode == VehicleMode.jeepney).toList();
    final walkOption =
        scored.where((r) => r.primaryMode == VehicleMode.walk).firstOrNull;

    if (jeepneyOptions.isEmpty) {
      if (publicTransport.isEmpty) return 0;
      return scored.indexOf(publicTransport.first);
    }

    final shortWalk = walkOption != null &&
        walkOption.walkingDistanceMeters < 600 &&
        walkOption.totalDistanceMeters < 900;

    if (shortWalk) return scored.indexOf(walkOption);

    final longWalkJeepney = jeepneyOptions.any(
      (r) => r.walkingDistanceMeters > RouteScorer.longWalkThresholdMeters,
    );
    final feederJeepney = jeepneyOptions
        .where((r) => r.steps.any((s) => s.type == RouteStepType.tricycle))
        .toList();

    final pool = longWalkJeepney && feederJeepney.isNotEmpty
        ? feederJeepney
        : jeepneyOptions;

    return scored.indexOf(pool.first);
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
    final hasFeeder = route.steps.any((s) => s.type == RouteStepType.tricycle) &&
        route.steps.any((s) => s.type == RouteStepType.jeepney);

    if (labels.contains(RouteLabel.recommended) && hasFeeder) {
      return 'Tricycle to the nearest PUJ stop, then jeepney — the usual Butuan pattern.';
    }
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

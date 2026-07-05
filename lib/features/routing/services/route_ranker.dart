import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/route_scorer.dart';

/// Ranks candidates, assigns labels, and picks the recommended option.
class RouteRanker {
  const RouteRanker({RouteScorer? scorer}) : _scorer = scorer ?? const RouteScorer();

  final RouteScorer _scorer;

  static const maxDisplayedOptions = 8;

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

    final labeled = scored.asMap().entries.map((entry) {
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

    return _capOptions(labeled);
  }

  List<PlannedRoute> _capOptions(List<PlannedRoute> routes) {
    if (routes.length <= maxDisplayedOptions) return routes;

    final kept = <PlannedRoute>[];
    final seenModes = <String>{};

    for (final route in routes) {
      final key = _optionKey(route);
      if (seenModes.contains(key)) continue;
      seenModes.add(key);
      kept.add(route);
      if (kept.length >= maxDisplayedOptions) break;
    }

    final recommended = routes.where((r) => r.isRecommended).firstOrNull;
    if (recommended != null && !kept.any((r) => r.optionId == recommended.optionId)) {
      kept.insert(0, recommended);
      if (kept.length > maxDisplayedOptions) kept.removeLast();
    }

    return kept;
  }

  String _optionKey(PlannedRoute route) {
    final modes = route.steps
        .where((s) => s.distanceMeters > 0 && s.type != RouteStepType.walk)
        .map((s) => s.type == RouteStepType.jeepney ? (s.routeCode ?? 'jeep') : s.type.name)
        .join('+');
    return modes.isEmpty ? route.primaryMode.name : modes;
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
        return _balancedRecommendation(scored, cheapest, fastest);
    }
  }

  int _indexOf(List<PlannedRoute> scored, PlannedRoute? target) {
    if (target == null) return 0;
    final idx = scored.indexWhere((r) => r.optionId == target.optionId);
    return idx >= 0 ? idx : 0;
  }

  int _balancedRecommendation(
    List<PlannedRoute> scored,
    PlannedRoute? cheapest,
    PlannedRoute? fastest,
  ) {
    final nonTaxi = scored.where((r) => r.primaryMode != VehicleMode.taxi).toList();
    if (nonTaxi.isEmpty) return 0;

    final cheap = cheapest ?? nonTaxi.first;
    final fast = fastest ?? nonTaxi.first;

    final jeepOptions = nonTaxi
        .where((r) => r.steps.any((s) => s.type == RouteStepType.jeepney))
        .toList();
    final directTrike =
        nonTaxi.where((r) => r.primaryMode == VehicleMode.tricycle).firstOrNull;

    if (jeepOptions.isNotEmpty && directTrike != null) {
      final longTrip = directTrike.totalDistanceMeters > 3500;
      final trikeNotCheaper =
          directTrike.estimatedFare >= jeepOptions.first.estimatedFare + 5;
      if (longTrip || trikeNotCheaper) {
        final feeder = jeepOptions.where(_hasOriginFeeder).firstOrNull;
        if (feeder != null) return scored.indexOf(feeder);
        return scored.indexOf(jeepOptions.first);
      }
    }

    if (directTrike != null && directTrike.totalDistanceMeters < 4500) {
      final jeepAlt = jeepOptions.firstOrNull;
      if (jeepAlt == null ||
          directTrike.estimatedFare <= jeepAlt.estimatedFare + 5) {
        return scored.indexOf(directTrike);
      }
    }

    final feederJeep = nonTaxi.where(_hasOriginFeeder).toList();
    final plainJeep = nonTaxi
        .where(
          (r) =>
              r.steps.any((s) => s.type == RouteStepType.jeepney) && !_hasOriginFeeder(r),
        )
        .toList();

    if (feederJeep.isNotEmpty) {
      final bestFeeder = feederJeep.first;
      if (plainJeep.isEmpty ||
          plainJeep.first.walkingDistanceMeters > RouteScorer.longWalkThresholdMeters) {
        return scored.indexOf(bestFeeder);
      }
    }

    if (cheap.optionId != fast.optionId) {
      final timeSaved = cheap.totalDurationSeconds - fast.totalDurationSeconds;
      final timeSavedPct = timeSaved / cheap.totalDurationSeconds;
      if (timeSavedPct >= 0.25 && fast.estimatedFare <= cheap.estimatedFare + 15) {
        return scored.indexOf(fast);
      }
    }

    if (cheap.primaryMode == VehicleMode.tricycle &&
        cheap.totalDistanceMeters > RouteScorer.shortTricycleBoostMeters) {
      final jeep = jeepOptions.firstOrNull;
      if (jeep != null) return scored.indexOf(jeep);
    }

    return scored.indexOf(cheap);
  }

  bool _hasOriginFeeder(PlannedRoute route) {
    final triIdx = route.steps.indexWhere((s) => s.type == RouteStepType.tricycle);
    final jeepIdx = route.steps.indexWhere((s) => s.type == RouteStepType.jeepney);
    return triIdx >= 0 && jeepIdx > triIdx;
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
    final hasFeeder = _hasOriginFeeder(route);

    if (labels.contains(RouteLabel.recommended) && hasFeeder) {
      return 'Tricycle to the nearest PUJ corridor crossing, then jeepney — typical Butuan pattern.';
    }
    if (labels.contains(RouteLabel.recommended) &&
        route.primaryMode == VehicleMode.tricycle) {
      return 'Direct tricycle is the simplest and most affordable for this distance.';
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

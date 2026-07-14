import 'package:pinpoint/features/map/domain/map_models.dart';

/// Computes fares from the administrator fare matrix and optional per-route overrides.
class FareCalculator {
  const FareCalculator({
    required this.jeepney,
    required this.tricycle,
    required this.taxi,
    this.bus,
    this.van,
    this.modernJeepney,
  });

  final FareConfig jeepney;
  final FareConfig tricycle;
  final FareConfig taxi;
  final FareConfig? bus;
  final FareConfig? van;
  final FareConfig? modernJeepney;

  factory FareCalculator.fromConfigs(List<FareConfig> fares) {
    FareConfig find(String type, double min, double rate) => fares.firstWhere(
          (f) => f.transportType == type,
          orElse: () => FareConfig(
            transportType: type,
            minimumFare: min,
            succeedingRate: rate,
          ),
        );
    return FareCalculator(
      jeepney: find('jeepney', 13, 1.8),
      tricycle: find('tricycle', 15, 2),
      taxi: find('taxi', 40, 13.5),
      bus: find('bus', 15, 2.0),
      van: find('van', 20, 2.5),
      modernJeepney: find('modern_jeepney', 15, 2.0),
    );
  }

  double jeepneyFare(double distanceMeters) =>
      jeepney.computeFare(distanceMeters / 1000);

  double tricycleFare(double distanceMeters, {double? zoneBaseFare}) {
    final computed = tricycle.computeFare(distanceMeters / 1000);
    if (zoneBaseFare != null) return zoneBaseFare > computed ? zoneBaseFare : computed;
    return computed;
  }

  double taxiFare(double distanceMeters) => taxi.computeFare(distanceMeters / 1000);

  /// Fare for a corridor vehicle, preferring per-route base/additional when set.
  double corridorFare(JeepneyRoute route, double distanceMeters) {
    if (route.baseFare != null) {
      final km = distanceMeters / 1000;
      final extra = route.additionalFare ?? 0;
      if (km <= 4) return route.baseFare!;
      return route.baseFare! + ((km - 4) * extra);
    }

    return switch (route.vehicleType) {
      'tricycle' => tricycleFare(distanceMeters),
      'taxi' => taxiFare(distanceMeters),
      'bus' => (bus ?? jeepney).computeFare(distanceMeters / 1000),
      'van' => (van ?? jeepney).computeFare(distanceMeters / 1000),
      'modern_jeepney' => (modernJeepney ?? jeepney).computeFare(distanceMeters / 1000),
      _ => jeepneyFare(distanceMeters),
    };
  }
}

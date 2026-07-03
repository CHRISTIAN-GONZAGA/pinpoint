import 'package:pinpoint/features/map/domain/map_models.dart';

/// Computes fares from the administrator fare matrix.
class FareCalculator {
  const FareCalculator({
    required this.jeepney,
    required this.tricycle,
    required this.taxi,
  });

  final FareConfig jeepney;
  final FareConfig tricycle;
  final FareConfig taxi;

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
}

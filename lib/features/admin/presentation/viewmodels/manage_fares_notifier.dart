import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';

class VehicleFareDraft {
  const VehicleFareDraft({
    required this.transportType,
    required this.label,
    required this.hint,
    this.fareId,
    this.minimumFare = 0,
    this.succeedingRate = 0,
  });

  final int? fareId;
  final String transportType;
  final String label;
  final String hint;
  final double minimumFare;
  final double succeedingRate;

  VehicleFareDraft copyWith({
    int? fareId,
    double? minimumFare,
    double? succeedingRate,
  }) {
    return VehicleFareDraft(
      fareId: fareId ?? this.fareId,
      transportType: transportType,
      label: label,
      hint: hint,
      minimumFare: minimumFare ?? this.minimumFare,
      succeedingRate: succeedingRate ?? this.succeedingRate,
    );
  }
}

class ManageFaresState {
  const ManageFaresState({
    this.fares = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<VehicleFareDraft> fares;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  static const defaults = <VehicleFareDraft>[
    VehicleFareDraft(
      transportType: 'jeepney',
      label: 'PUJ / Jeepney',
      hint: 'Minimum usually covers the first 4 km',
      minimumFare: 13,
      succeedingRate: 1.8,
    ),
    VehicleFareDraft(
      transportType: 'tricycle',
      label: 'Tricycle',
      hint: 'Used when no zone base fare applies',
      minimumFare: 15,
      succeedingRate: 2,
    ),
    VehicleFareDraft(
      transportType: 'taxi',
      label: 'Taxi',
      hint: 'Flag-down + per succeeding km',
      minimumFare: 40,
      succeedingRate: 13.5,
    ),
  ];

  ManageFaresState copyWith({
    List<VehicleFareDraft>? fares,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ManageFaresState(
      fares: fares ?? this.fares,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ManageFaresNotifier extends Notifier<ManageFaresState> {
  @override
  ManageFaresState build() => const ManageFaresState(fares: ManageFaresState.defaults);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final raw = await ref.read(adminRepositoryProvider).getAdminFares();
      final byType = {
        for (final item in raw) item['transport_type'] as String: item,
      };
      final fares = ManageFaresState.defaults.map((draft) {
        final row = byType[draft.transportType];
        if (row == null) return draft;
        return draft.copyWith(
          fareId: row['fare_id'] as int?,
          minimumFare: (row['minimum_fare'] as num?)?.toDouble() ?? draft.minimumFare,
          succeedingRate:
              (row['succeeding_rate'] as num?)?.toDouble() ?? draft.succeedingRate,
        );
      }).toList();
      state = state.copyWith(isLoading: false, fares: fares);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void updateDraft(String transportType, {double? minimumFare, double? succeedingRate}) {
    state = state.copyWith(
      fares: [
        for (final fare in state.fares)
          if (fare.transportType == transportType)
            fare.copyWith(minimumFare: minimumFare, succeedingRate: succeedingRate)
          else
            fare,
      ],
    );
  }

  Future<bool> saveAll() async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      for (final fare in state.fares) {
        final payload = {
          'minimum_fare': fare.minimumFare,
          'succeeding_rate': fare.succeedingRate,
        };
        if (fare.fareId != null) {
          await repo.updateFare(fare.fareId!, payload);
        } else {
          await repo.upsertFareByType(fare.transportType, payload);
        }
      }
      await load();
      try {
        await ref.read(transportRepositoryProvider).refreshFromRemote();
      } catch (_) {}
      state = state.copyWith(isSaving: false, successMessage: 'Fare rates saved');
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

final manageFaresNotifierProvider =
    NotifierProvider<ManageFaresNotifier, ManageFaresState>(ManageFaresNotifier.new);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_fares_notifier.dart';

/// Admin editor for PUJ / tricycle / taxi minimum + per-km rates.
class ManageFaresScreen extends ConsumerStatefulWidget {
  const ManageFaresScreen({super.key});

  @override
  ConsumerState<ManageFaresScreen> createState() => _ManageFaresScreenState();
}

class _ManageFaresScreenState extends ConsumerState<ManageFaresScreen> {
  final _controllers = <String, ({TextEditingController min, TextEditingController rate})>{};

  @override
  void initState() {
    super.initState();
    for (final draft in ManageFaresState.defaults) {
      _controllers[draft.transportType] = (
        min: TextEditingController(),
        rate: TextEditingController(),
      );
    }
    Future.microtask(() => ref.read(manageFaresNotifierProvider.notifier).load());
  }

  @override
  void dispose() {
    for (final pair in _controllers.values) {
      pair.min.dispose();
      pair.rate.dispose();
    }
    super.dispose();
  }

  void _syncControllers(ManageFaresState state) {
    for (final fare in state.fares) {
      final pair = _controllers[fare.transportType];
      if (pair == null) continue;
      final minText = _formatNumber(fare.minimumFare);
      final rateText = _formatNumber(fare.succeedingRate);
      if (pair.min.text != minText) pair.min.text = minText;
      if (pair.rate.text != rateText) pair.rate.text = rateText;
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _save() async {
    final notifier = ref.read(manageFaresNotifierProvider.notifier);
    for (final entry in _controllers.entries) {
      final min = double.tryParse(entry.value.min.text.trim());
      final rate = double.tryParse(entry.value.rate.text.trim());
      if (min == null || rate == null || min < 0 || rate < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid non-negative fare amounts.')),
        );
        return;
      }
      notifier.updateDraft(entry.key, minimumFare: min, succeedingRate: rate);
    }
    final ok = await notifier.saveAll();
    if (!mounted) return;
    if (ok) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fares updated'),
          content: const Text(
            'Passenger route estimates will use these minimum and per-kilometer rates.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manageFaresNotifierProvider);
    final theme = Theme.of(context);

    ref.listen(manageFaresNotifierProvider, (prev, next) {
      _syncControllers(next);
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Fares'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                Text(
                  'Set the normal charge for each vehicle type. '
                  'Minimum fare covers the first 4 km; the per-km rate applies after that.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...state.fares.map((fare) {
                  final pair = _controllers[fare.transportType]!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fare.label, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(fare.hint, style: theme.textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: pair.min,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Minimum / flag-down (₱)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: pair.rate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Charge per succeeding km (₱)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: state.isSaving ? null : _save,
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save fare rates'),
                ),
              ],
            ),
    );
  }
}

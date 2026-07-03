import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinpoint/core/services/route_pdf_service.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/transport_colors.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom sheet showing generated route summary, vehicle options, and steps.
class RouteSummarySheet extends StatelessWidget {
  const RouteSummarySheet({
    super.key,
    required this.route,
    required this.routeOptions,
    required this.onClose,
    required this.onGenerate,
    required this.onSelectOption,
    required this.onVehicleModeChanged,
    this.onPreviewOption,
    this.onStepTap,
    this.isGenerating = false,
    this.canGenerate = false,
    this.originLabel,
    this.destinationLabel,
    this.selectedVehicleMode = VehicleMode.auto,
    this.highlightedStepIndex,
  });

  final PlannedRoute? route;
  final List<PlannedRoute> routeOptions;
  final VoidCallback onClose;
  final VoidCallback onGenerate;
  final ValueChanged<PlannedRoute> onSelectOption;
  final ValueChanged<PlannedRoute?>? onPreviewOption;
  final ValueChanged<int>? onStepTap;
  final ValueChanged<VehicleMode> onVehicleModeChanged;
  final bool isGenerating;
  final bool canGenerate;
  final String? originLabel;
  final String? destinationLabel;
  final VehicleMode selectedVehicleMode;
  final int? highlightedStepIndex;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: route != null ? 0.45 : 0.22,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.18, 0.45, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (route == null) ...[
                Text('Plan Your Route', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  canGenerate
                      ? 'Tap anywhere on the map to set start or destination.'
                      : 'Move the map freely, then tap a location for options.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _VehicleModeSelector(
                  selected: selectedVehicleMode,
                  onChanged: onVehicleModeChanged,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: canGenerate && !isGenerating ? onGenerate : null,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.route_rounded),
                  label: Text(isGenerating ? 'Comparing routes...' : 'Compare Routes'),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text('Route Summary', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Export PDF',
                      onPressed: () => _exportPdf(context),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                    IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                  ],
                ),
                if (route!.warningMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _WarningBanner(message: route!.warningMessage!),
                ],
                if (routeOptions.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  _RouteOptionPicker(
                    options: routeOptions,
                    selected: route!,
                    onSelect: onSelectOption,
                    onPreview: onPreviewOption,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _StatChip(icon: Icons.schedule, label: route!.durationLabel),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(icon: Icons.straighten, label: route!.distanceLabel),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      icon: Icons.payments_outlined,
                      label: '₱${route!.estimatedFare.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                if (route!.transferCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${route!.transferCount} transfer${route!.transferCount > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Directions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ...route!.steps.asMap().entries.map(
                      (entry) => _StepTile(
                        index: entry.key + 1,
                        step: entry.value,
                        isHighlighted: highlightedStepIndex == entry.key,
                        onTap: onStepTap != null ? () => onStepTap!(entry.key) : null,
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    if (route == null) return;
    try {
      final bytes = await RoutePdfService().generate(
        route: route!,
        originLabel: originLabel ?? 'Start',
        destinationLabel: destinationLabel ?? 'Destination',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pinpoint-route.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'PINPOINT route summary');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PDF: $error')),
        );
      }
    }
  }
}

class _VehicleModeSelector extends StatelessWidget {
  const _VehicleModeSelector({required this.selected, required this.onChanged});

  final VehicleMode selected;
  final ValueChanged<VehicleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<VehicleMode>(
      segments: const [
        ButtonSegment(value: VehicleMode.auto, label: Text('Auto'), icon: Icon(Icons.auto_awesome, size: 16)),
        ButtonSegment(value: VehicleMode.jeepney, label: Text('Jeep'), icon: Icon(Icons.directions_bus, size: 16)),
        ButtonSegment(value: VehicleMode.tricycle, label: Text('Trike'), icon: Icon(Icons.moped, size: 16)),
        ButtonSegment(value: VehicleMode.taxi, label: Text('Taxi'), icon: Icon(Icons.local_taxi, size: 16)),
      ],
      selected: {selected},
      onSelectionChanged: (modes) => onChanged(modes.first),
    );
  }
}

class _RouteOptionPicker extends StatelessWidget {
  const _RouteOptionPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.onPreview,
  });

  final List<PlannedRoute> options;
  final PlannedRoute selected;
  final ValueChanged<PlannedRoute> onSelect;
  final ValueChanged<PlannedRoute?>? onPreview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.primaryMode == selected.primaryMode;
          final color = _modeColor(option.primaryMode);
          final stars = _ratingStars(option);
          return InkWell(
            onTap: () => onSelect(option),
            onHighlightChanged: (highlighted) {
              if (onPreview == null) return;
              onPreview!(highlighted ? option : null);
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 136,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected ? color.withValues(alpha: 0.08) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(_modeIcon(option.primaryMode), size: 16, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          option.isRecommended ? 'Recommended' : _modeLabel(option.primaryMode),
                          style: Theme.of(context).textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${option.estimatedFare.toStringAsFixed(0)} · ${option.durationLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${option.walkingDistanceMeters.round()} m walk',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  if (option.warningMessage != null)
                    Text(
                      'Highway restricted',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _ratingStars(PlannedRoute option) {
    var score = 3;
    if (option.isRecommended) score += 1;
    if (option.walkingDistanceMeters < 300) score += 1;
    if (option.transferCount == 0) score += 1;
    if (option.estimatedFare > 80) score -= 1;
    return score.clamp(1, 5);
  }

  Color _modeColor(VehicleMode mode) => switch (mode) {
        VehicleMode.jeepney => TransportColors.jeepney('R1'),
        VehicleMode.tricycle => TransportColors.tricycle,
        VehicleMode.taxi => TransportColors.taxi,
        VehicleMode.auto => AppColors.primary,
      };

  IconData _modeIcon(VehicleMode mode) => switch (mode) {
        VehicleMode.jeepney => Icons.directions_bus_rounded,
        VehicleMode.tricycle => Icons.moped_rounded,
        VehicleMode.taxi => Icons.local_taxi_rounded,
        VehicleMode.auto => Icons.auto_awesome_rounded,
      };

  String _modeLabel(VehicleMode mode) => switch (mode) {
        VehicleMode.jeepney => 'Jeepney',
        VehicleMode.tricycle => 'Tricycle',
        VehicleMode.taxi => 'Taxi',
        VehicleMode.auto => 'Best',
      };
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: Theme.of(context).textTheme.labelMedium),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    this.isHighlighted = false,
    this.onTap,
  });

  final int index;
  final RouteStep step;
  final bool isHighlighted;
  final VoidCallback? onTap;

  IconData get _icon => switch (step.type) {
        RouteStepType.walk => Icons.directions_walk_rounded,
        RouteStepType.jeepney => Icons.directions_bus_rounded,
        RouteStepType.tricycle => Icons.moped_rounded,
        RouteStepType.taxi => Icons.local_taxi_rounded,
        RouteStepType.transfer => Icons.swap_horiz_rounded,
      };

  Color get _color => switch (step.type) {
        RouteStepType.walk => TransportColors.walk,
        RouteStepType.jeepney => step.segmentColorHex != null
            ? colorFromHex(step.segmentColorHex!)
            : TransportColors.jeepney(step.routeCode),
        RouteStepType.tricycle => TransportColors.tricycle,
        RouteStepType.taxi => TransportColors.taxi,
        RouteStepType.transfer => TransportColors.transfer,
      };

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isHighlighted
                ? _color
                : _color.withValues(alpha: 0.15),
            child: Text(
              '$index',
              style: TextStyle(
                color: isHighlighted ? Colors.white : _color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, size: 16, color: _color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(step.instruction, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
                if (step.distanceMeters > 0)
                  Text(
                    step.distanceMeters >= 1000
                        ? '${(step.distanceMeters / 1000).toStringAsFixed(1)} km'
                        : '${step.distanceMeters.round()} m',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                if (step.durationSeconds > 0)
                  Text(
                    step.durationLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}

/// Bottom sheet for jeepney route details.
class JeepneyRouteSheet extends StatelessWidget {
  const JeepneyRouteSheet({super.key, required this.route, required this.onClose});

  final JeepneyRoute route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(route.colorHex);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.routeName, style: Theme.of(context).textTheme.titleMedium),
                    if (route.operatingHours != null)
                      Text(route.operatingHours!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          if (route.routeName.toLowerCase().contains('terminal') || route.stops.any((s) => s.name.toLowerCase().contains('terminal'))) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.directions_bus, size: 16),
                  label: Text('${route.stops.length} stops'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(route.routeCode),
                  backgroundColor: color.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Stops (${route.stops.length})', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ...route.stops.map(
            (stop) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text('${stop.order}', style: TextStyle(color: color, fontSize: 12)),
              ),
              title: Text(stop.name, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

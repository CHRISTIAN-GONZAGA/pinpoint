import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinpoint/core/services/route_pdf_service.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/domain/transport_colors.dart';
import 'package:share_plus/share_plus.dart';

/// Draggable bottom panel for route planning — content-sized, dismissible.
class RouteSummarySheet extends StatefulWidget {
  const RouteSummarySheet({
    super.key,
    required this.route,
    required this.routeOptions,
    required this.onClose,
    required this.onDismiss,
    required this.onGenerate,
    required this.onSelectOption,
    required this.onVehicleModeChanged,
    this.sheetController,
    this.onPreferenceChanged,
    this.selectedRoutePreference = RoutePreference.balanced,
    this.onPreviewOption,
    this.onStepTap,
    this.isGenerating = false,
    this.canGenerate = false,
    this.originLabel,
    this.destinationLabel,
    this.selectedVehicleMode = VehicleMode.auto,
    this.highlightedStepIndex,
    this.onSwap,
    this.isLocating = false,
    this.locationWarning,
    this.onUseLocation,
    this.onOpenLocationSettings,
  });

  final PlannedRoute? route;
  final List<PlannedRoute> routeOptions;
  final VoidCallback onClose;
  final VoidCallback onDismiss;
  final VoidCallback onGenerate;
  final ValueChanged<PlannedRoute> onSelectOption;
  final ValueChanged<PlannedRoute?>? onPreviewOption;
  final ValueChanged<int>? onStepTap;
  final ValueChanged<VehicleMode> onVehicleModeChanged;
  final ValueChanged<RoutePreference>? onPreferenceChanged;
  final RoutePreference selectedRoutePreference;
  final bool isGenerating;
  final bool canGenerate;
  final String? originLabel;
  final String? destinationLabel;
  final VoidCallback? onSwap;
  final bool isLocating;
  final String? locationWarning;
  final VoidCallback? onUseLocation;
  final VoidCallback? onOpenLocationSettings;
  final VehicleMode selectedVehicleMode;
  final int? highlightedStepIndex;
  final DraggableScrollableController? sheetController;

  @override
  State<RouteSummarySheet> createState() => _RouteSummarySheetState();
}

class _RouteSummarySheetState extends State<RouteSummarySheet> {
  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.route != null;

    return DraggableScrollableSheet(
      controller: widget.sheetController,
      initialChildSize: hasRoute ? 0.42 : 0.18,
      minChildSize: 0.14,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: hasRoute
          ? const [0.18, 0.42, 0.72, 0.92]
          : const [0.14, 0.18, 0.42],
      shouldCloseOnMinExtent: false,
      builder: (context, scrollController) {
        return Material(
          elevation: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Large grab area so the sheet is easy to drag above the nav.
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasRoute ? 'Swipe up for full route details' : 'Route planner',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hide',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: _sheetContent(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sheetContent(BuildContext context) {
    final route = widget.route;
    return [
      if (widget.originLabel != null || widget.destinationLabel != null)
        _EndpointPlate(
          originLabel: widget.originLabel,
          destinationLabel: widget.destinationLabel,
          isLocating: widget.isLocating,
          locationWarning: widget.locationWarning,
          onSwap: widget.onSwap,
          onUseLocation: widget.onUseLocation,
          onOpenLocationSettings: widget.onOpenLocationSettings,
        ),
      if (route == null) ...[
        Text('Plan a route', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          widget.canGenerate
              ? 'Ready to compare routes'
              : 'Set start & destination on the map',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        _VehicleModeSelector(
          selected: widget.selectedVehicleMode,
          onChanged: widget.onVehicleModeChanged,
        ),
        if (widget.onPreferenceChanged != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _PreferenceSelector(
            selected: widget.selectedRoutePreference,
            onChanged: widget.onPreferenceChanged!,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (widget.isGenerating) ...[
          Text(
            'Comparing walk, jeepney, tricycle & taxi…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _RouteOptionsSkeleton(),
        ] else
          FilledButton.icon(
            onPressed: widget.canGenerate ? widget.onGenerate : null,
            icon: const Icon(Icons.route_rounded),
            label: const Text('Compare routes'),
          ),
      ] else if (widget.isGenerating) ...[
        Text('Route Summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const _RouteOptionsSkeleton(),
        const SizedBox(height: AppSpacing.md),
        const _RouteStepsSkeleton(),
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
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
          ],
        ),
        if (route.warningMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _WarningBanner(message: route.warningMessage!),
        ],
        if (widget.routeOptions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _RouteOptionPicker(
            options: widget.routeOptions,
            selected: route,
            onSelect: widget.onSelectOption,
            onPreview: widget.onPreviewOption,
          ),
        ],
        if (route.explanation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            route.explanation!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (route.summaryTitle != null)
          Text(
            route.summaryTitle!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _StatChip(icon: Icons.schedule, label: route.durationLabel),
            const SizedBox(width: AppSpacing.sm),
            _StatChip(icon: Icons.flag_outlined, label: route.arrivalLabel),
            const SizedBox(width: AppSpacing.sm),
            _StatChip(
              icon: Icons.payments_outlined,
              label: '₱${route.estimatedFare.toStringAsFixed(0)}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _StatChip(
              icon: Icons.directions_walk,
              label: '${route.walkingDistanceMeters.round()} m walk',
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatChip(icon: Icons.flag_outlined, label: route.arrivalLabel),
          ],
        ),
        if (route.transferCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${route.transferCount} transfer${route.transferCount > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.warning,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Directions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...route.steps.asMap().entries.map(
              (entry) => _StepTile(
                index: entry.key + 1,
                step: entry.value,
                isHighlighted: widget.highlightedStepIndex == entry.key,
                onTap: widget.onStepTap != null ? () => widget.onStepTap!(entry.key) : null,
              ),
            ),
      ],
    ];
  }

  Future<void> _exportPdf(BuildContext context) async {
    final route = widget.route;
    if (route == null) return;
    try {
      final bytes = await RoutePdfService().generate(
        route: route,
        originLabel: widget.originLabel ?? 'Start',
        destinationLabel: widget.destinationLabel ?? 'Destination',
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

class _EndpointPlate extends StatelessWidget {
  const _EndpointPlate({
    required this.originLabel,
    required this.destinationLabel,
    required this.isLocating,
    required this.locationWarning,
    this.onSwap,
    this.onUseLocation,
    this.onOpenLocationSettings,
  });

  final String? originLabel;
  final String? destinationLabel;
  final bool isLocating;
  final String? locationWarning;
  final VoidCallback? onSwap;
  final VoidCallback? onUseLocation;
  final VoidCallback? onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.inkOf(brightness);
    final muted = AppColors.inkSecondaryOf(brightness);
    final warning = locationWarning?.trim();
    final from = isLocating
        ? 'Finding your location…'
        : (originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : 'Current location');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paperOf(brightness),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.edgeOf(brightness), width: 2),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 56, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryFillOf(brightness), width: 3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                            if (isLocating)
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              )
                            else
                              Text(from, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (warning != null && warning.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      warning,
                      style: TextStyle(
                        color: brightness == Brightness.dark
                            ? AppColors.dangerTextDark
                            : AppColors.dangerText,
                        fontSize: 13,
                      ),
                    ),
                    if (onOpenLocationSettings != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onOpenLocationSettings,
                          child: const Text('Open settings'),
                        ),
                      ),
                  ] else if (!isLocating && (originLabel == null || originLabel!.trim().isEmpty) && onUseLocation != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onUseLocation,
                        child: const Text('Turn on location'),
                      ),
                    ),
                  Divider(height: 18, color: AppColors.hairlineOf(brightness)),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: AppColors.dangerOf(brightness),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(
                              destinationLabel?.trim().isNotEmpty == true ? destinationLabel!.trim() : 'Choose a destination',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSwap != null)
              Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    tooltip: 'Swap start and destination',
                    onPressed: onSwap,
                    icon: const Icon(Icons.swap_vert),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceSelector extends StatelessWidget {
  const _PreferenceSelector({required this.selected, required this.onChanged});

  final RoutePreference selected;
  final ValueChanged<RoutePreference> onChanged;

  static const _prefs = [
    (RoutePreference.balanced, 'Best value'),
    (RoutePreference.cheapest, 'Cheapest'),
    (RoutePreference.fastest, 'Fastest'),
    (RoutePreference.leastWalking, 'Less walk'),
    (RoutePreference.fewestTransfers, 'Direct'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _prefs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (pref, label) = _prefs[index];
          return FilterChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: selected == pref,
            onSelected: (_) => onChanged(pref),
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _VehicleModeSelector extends StatelessWidget {
  const _VehicleModeSelector({required this.selected, required this.onChanged});

  final VehicleMode selected;
  final ValueChanged<VehicleMode> onChanged;

  static const _modes = [
    (VehicleMode.auto, Icons.auto_awesome, 'Auto'),
    (VehicleMode.walk, Icons.directions_walk, 'Walk'),
    (VehicleMode.jeepney, Icons.directions_bus, 'Jeep'),
    (VehicleMode.tricycle, Icons.moped, 'Trike'),
    (VehicleMode.taxi, Icons.local_taxi, 'Taxi'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (mode, icon, label) = _modes[index];
          return ChoiceChip(
            label: Text(label),
            selected: selected == mode,
            avatar: Icon(icon, size: 16),
            onSelected: (_) => onChanged(mode),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
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
    final brightness = Theme.of(context).brightness;
    final edge = AppColors.edgeOf(brightness);
    final ink = AppColors.inkOf(brightness);
    return Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final option = options[index];
              final isSelected = option.optionId == selected.optionId;
              final tag = _cardTitle(option, options);
              final best = index == 0 || option.isRecommended;
              return Material(
                color: AppColors.paperOf(brightness),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onSelect(option),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryFillOf(brightness) : edge,
                        width: isSelected ? 3 : 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.durationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: ink),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final step in option.steps) ...[
                              Icon(_modeIcon(step.type == RouteStepType.walk ? VehicleMode.walk : option.primaryMode), size: 18),
                              if (step.routeCode != null && step.routeCode!.isNotEmpty)
                                Text(
                                  step.routeCode!,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: best ? AppColors.signal : AppColors.sunkenOf(brightness),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: best ? AppColors.ink : ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Fare ₱${option.estimatedFare.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _cardTitle(PlannedRoute option, List<PlannedRoute> options) {
    if (option.isRecommended) return 'Best value';
    final minFare = options.map((o) => o.estimatedFare).reduce((a, b) => a < b ? a : b);
    final minTime = options.map((o) => o.totalDurationSeconds).reduce((a, b) => a < b ? a : b);
    if (option.estimatedFare <= minFare + 0.01) return 'Cheapest';
    if (option.totalDurationSeconds <= minTime) return 'Fastest';
    return _modeLabel(option.primaryMode);
  }

  IconData _modeIcon(VehicleMode mode) => switch (mode) {
        VehicleMode.jeepney ||
        VehicleMode.modernJeepney ||
        VehicleMode.bus ||
        VehicleMode.van =>
          Icons.directions_bus_rounded,
        VehicleMode.tricycle => Icons.moped_rounded,
        VehicleMode.taxi => Icons.local_taxi_rounded,
        VehicleMode.walk => Icons.directions_walk_rounded,
        VehicleMode.auto => Icons.auto_awesome_rounded,
      };

  String _modeLabel(VehicleMode mode) => switch (mode) {
        VehicleMode.jeepney => 'Jeepney',
        VehicleMode.modernJeepney => 'Modern Jeepney',
        VehicleMode.bus => 'Bus',
        VehicleMode.van => 'Van',
        VehicleMode.tricycle => 'Tricycle',
        VehicleMode.taxi => 'Taxi',
        VehicleMode.walk => 'Walk',
        VehicleMode.auto => 'Best',
      };
}

class _RouteOptionsSkeleton extends StatelessWidget {
  const _RouteOptionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, __) => const SizedBox(
          width: 148,
          child: LoadingShimmer(height: 108, borderRadius: 14),
        ),
      ),
    );
  }
}

class _RouteStepsSkeleton extends StatelessWidget {
  const _RouteStepsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: LoadingShimmer(height: 52, borderRadius: 10),
        ),
      ),
    );
  }
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
        RouteStepType.jeepney ||
        RouteStepType.modernJeepney ||
        RouteStepType.bus ||
        RouteStepType.van =>
          Icons.directions_bus_rounded,
        RouteStepType.tricycle => Icons.moped_rounded,
        RouteStepType.taxi => Icons.local_taxi_rounded,
        RouteStepType.transfer => Icons.swap_horiz_rounded,
      };

  Color get _color => switch (step.type) {
        RouteStepType.walk => TransportColors.walk,
        RouteStepType.jeepney ||
        RouteStepType.modernJeepney ||
        RouteStepType.bus ||
        RouteStepType.van =>
          step.segmentColorHex != null
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

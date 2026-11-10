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

/// Draggable bottom panel for route planning — flush to nav bar, dismissible.
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
    // Include bottom nav bar height so sheet content is never clipped behind it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
        final brightness = Theme.of(context).brightness;
        final isDark = brightness == Brightness.dark;
        return Material(
          elevation: 0,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paperOf(brightness),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.edgeDark.withValues(alpha: 0.7) : AppColors.edge.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                left: BorderSide(
                  color: isDark ? AppColors.edgeDark.withValues(alpha: 0.5) : AppColors.edge.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                right: BorderSide(
                  color: isDark ? AppColors.edgeDark.withValues(alpha: 0.5) : AppColors.edge.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Drag handle + hint ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.hairlineOf(brightness),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasRoute ? 'Swipe up for full route details' : 'Route planner',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.inkSecondaryOf(brightness).withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hide panel',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onDismiss,
                        icon: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.sunkenOf(brightness),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      // Extra bottom padding = nav bar height so last item is always reachable
                      AppSpacing.lg + bottomInset,
                    ),
                    children: _sheetContent(context),
                  ),
                ),
              ],
            ),
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
        Text('Plan a route', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          widget.canGenerate
              ? 'Ready to compare routes'
              : 'Set start & destination on the map',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
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
                  color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _RouteOptionsSkeleton(),
        ] else
          FilledButton.icon(
            onPressed: widget.canGenerate ? widget.onGenerate : null,
            icon: const Icon(Icons.route_rounded),
            label: const Text('Compare routes'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
      ] else if (widget.isGenerating) ...[
        Text('Route Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        const _RouteOptionsSkeleton(),
        const SizedBox(height: AppSpacing.md),
        const _RouteStepsSkeleton(),
      ] else ...[
        Row(
          children: [
            Expanded(
              child: Text('Route Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: () => _exportPdf(context),
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sunkenOf(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              ),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sunkenOf(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, size: 18),
              ),
            ),
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
                  color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (route.summaryTitle != null)
          Text(
            route.summaryTitle!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: AppSpacing.sm),
        // Stat row — premium pill chips
        _StatRow(route: route),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('Directions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              '${route.steps.length} steps',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...route.steps.asMap().entries.map(
              (entry) => _StepTile(
                index: entry.key + 1,
                step: entry.value,
                isLast: entry.key == route.steps.length - 1,
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

// ── Endpoint plate ──────────────────────────────────────────────────────────

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
    final isDark = brightness == Brightness.dark;
    final ink = AppColors.inkOf(brightness);
    final muted = AppColors.inkSecondaryOf(brightness);
    final primary = AppColors.primaryFillOf(brightness);
    final warning = locationWarning?.trim();
    final from = isLocating
        ? 'Finding your location…'
        : (originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : 'Current location');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paperOf(brightness),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.edgeDark.withValues(alpha: 0.7) : AppColors.edge.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 56, 14),
              child: Column(
                children: [
                  // ── Origin row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 2),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primary, width: 3),
                            ),
                          ),
                          // Dashed connector line between origin and destination
                          SizedBox(
                            width: 2,
                            height: 28,
                            child: CustomPaint(painter: _DashedLinePainter(color: AppColors.hairlineOf(brightness))),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            if (isLocating)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
                                  ),
                                ],
                              )
                            else
                              Text(from, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
                            if (warning != null && warning.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                warning,
                                style: TextStyle(
                                  color: isDark ? AppColors.dangerTextDark : AppColors.dangerText,
                                  fontSize: 12,
                                ),
                              ),
                              if (onOpenLocationSettings != null)
                                GestureDetector(
                                  onTap: onOpenLocationSettings,
                                  child: Text(
                                    'Open settings',
                                    style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ] else if (!isLocating && (originLabel == null || originLabel!.trim().isEmpty) && onUseLocation != null)
                              GestureDetector(
                                onTap: onUseLocation,
                                child: Text(
                                  'Turn on location',
                                  style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── Destination row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 2),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.dangerOf(brightness),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            Text(
                              destinationLabel?.trim().isNotEmpty == true
                                  ? destinationLabel!.trim()
                                  : 'Choose a destination',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 14),
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
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.sunkenOf(brightness),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Swap start and destination',
                      onPressed: onSwap,
                      icon: const Icon(Icons.swap_vert, size: 20),
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

/// Custom painter for dashed vertical connector line.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(size.width / 2, startY), Offset(size.width / 2, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

// ── Preference & vehicle selectors ─────────────────────────────────────────

class _PreferenceSelector extends StatelessWidget {
  const _PreferenceSelector({required this.selected, required this.onChanged});

  final RoutePreference selected;
  final ValueChanged<RoutePreference> onChanged;

  static const _prefs = [
    (RoutePreference.balanced, Icons.balance_rounded, 'Best value'),
    (RoutePreference.cheapest, Icons.savings_rounded, 'Cheapest'),
    (RoutePreference.fastest, Icons.flash_on_rounded, 'Fastest'),
    (RoutePreference.leastWalking, Icons.directions_walk_rounded, 'Less walk'),
    (RoutePreference.fewestTransfers, Icons.linear_scale_rounded, 'Direct'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _prefs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (pref, icon, label) = _prefs[index];
          final isSelected = selected == pref;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: FilterChip(
              label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
              avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.inkSecondaryOf(brightness)),
              selected: isSelected,
              onSelected: (_) => onChanged(pref),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              selectedColor: AppColors.primaryFillOf(brightness),
              labelStyle: TextStyle(color: isSelected ? Colors.white : null),
            ),
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
    (VehicleMode.auto, Icons.auto_awesome_rounded, 'Auto'),
    (VehicleMode.walk, Icons.directions_walk_rounded, 'Walk'),
    (VehicleMode.jeepney, Icons.directions_bus_rounded, 'Jeep'),
    (VehicleMode.tricycle, Icons.moped_rounded, 'Trike'),
    (VehicleMode.taxi, Icons.local_taxi_rounded, 'Taxi'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (mode, icon, label) = _modes[index];
          final isSelected = selected == mode;
          return ChoiceChip(
            label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
            selected: isSelected,
            avatar: Icon(icon, size: 16),
            onSelected: (_) => onChanged(mode),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

// ── Route options picker ────────────────────────────────────────────────────

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
    final isDark = brightness == Brightness.dark;
    return Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final option = options[index];
              final isSelected = option.optionId == selected.optionId;
              final tag = _cardTitle(option, options);
              final isBest = index == 0 || option.isRecommended;
              final modeColor = _primaryModeColor(option.primaryMode);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: modeColor.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: AppColors.paperOf(brightness),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => onSelect(option),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? modeColor : AppColors.hairlineOf(brightness),
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Colored left accent stripe
                          Container(
                            width: 5,
                            decoration: BoxDecoration(
                              color: modeColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.durationLabel,
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.inkOf(brightness),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isBest ? AppColors.signal : AppColors.sunkenOf(brightness),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isBest
                                                ? AppColors.ink
                                                : AppColors.inkSecondaryOf(brightness),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Mode icons with route codes
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      for (final step in option.steps) ...[
                                        Icon(
                                          _modeIcon(step.type == RouteStepType.walk ? VehicleMode.walk : option.primaryMode),
                                          size: 16,
                                          color: AppColors.inkSecondaryOf(brightness),
                                        ),
                                        if (step.routeCode != null && step.routeCode!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: modeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              step.routeCode!,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                                color: modeColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Fare ₱${option.estimatedFare.toStringAsFixed(0)}  ·  ${option.walkingDistanceMeters.round()} m walk',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppColors.inkSecondaryOf(brightness),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: modeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
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

  Color _primaryModeColor(VehicleMode mode) => switch (mode) {
    VehicleMode.jeepney || VehicleMode.modernJeepney || VehicleMode.bus || VehicleMode.van => AppColors.primary,
    VehicleMode.tricycle => AppColors.warning,
    VehicleMode.taxi => const Color(0xFFC9650F),
    VehicleMode.walk => AppColors.accent,
    VehicleMode.auto => AppColors.primary,
  };

  IconData _modeIcon(VehicleMode mode) => switch (mode) {
    VehicleMode.jeepney || VehicleMode.modernJeepney || VehicleMode.bus || VehicleMode.van => Icons.directions_bus_rounded,
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

// ── Stat row ────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({required this.route});
  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final stats = [
      (Icons.schedule_rounded, route.durationLabel, AppColors.primary),
      (Icons.flag_rounded, route.arrivalLabel, AppColors.accent),
      (Icons.payments_rounded, '₱${route.estimatedFare.toStringAsFixed(0)}', const Color(0xFFC9650F)),
    ];
    return Row(
      children: stats.asMap().entries.map((e) {
        final (icon, label, color) = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkOf(brightness),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Skeletons ───────────────────────────────────────────────────────────────

class _RouteOptionsSkeleton extends StatelessWidget {
  const _RouteOptionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LoadingShimmer(height: 90, borderRadius: 18),
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
          child: LoadingShimmer(height: 56, borderRadius: 12),
        ),
      ),
    );
  }
}

// ── Warning banner ──────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ── Step tile (timeline style) ──────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.isLast,
    this.isHighlighted = false,
    this.onTap,
  });

  final int index;
  final RouteStep step;
  final bool isLast;
  final bool isHighlighted;
  final VoidCallback? onTap;

  IconData get _icon => switch (step.type) {
    RouteStepType.walk => Icons.directions_walk_rounded,
    RouteStepType.jeepney || RouteStepType.modernJeepney || RouteStepType.bus || RouteStepType.van => Icons.directions_bus_rounded,
    RouteStepType.tricycle => Icons.moped_rounded,
    RouteStepType.taxi => Icons.local_taxi_rounded,
    RouteStepType.transfer => Icons.swap_horiz_rounded,
  };

  Color get _color => switch (step.type) {
    RouteStepType.walk => TransportColors.walk,
    RouteStepType.jeepney || RouteStepType.modernJeepney || RouteStepType.bus || RouteStepType.van =>
      step.segmentColorHex != null ? colorFromHex(step.segmentColorHex!) : TransportColors.jeepney(step.routeCode),
    RouteStepType.tricycle => TransportColors.tricycle,
    RouteStepType.taxi => TransportColors.taxi,
    RouteStepType.transfer => TransportColors.transfer,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final color = isHighlighted ? _color : _color.withValues(alpha: 0.6);

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline column
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isHighlighted ? _color : _color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, size: 18, color: isHighlighted ? Colors.white : _color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.hairlineOf(brightness),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      step.instruction,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (step.distanceMeters > 0) ...[
                          Text(
                            step.distanceMeters >= 1000
                                ? '${(step.distanceMeters / 1000).toStringAsFixed(1)} km'
                                : '${step.distanceMeters.round()} m',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.inkSecondaryOf(brightness),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (step.durationSeconds > 0)
                            Text(
                              '  ·  ${step.durationLabel}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.inkSecondaryOf(brightness).withValues(alpha: 0.7),
                              ),
                            ),
                        ] else if (step.durationSeconds > 0)
                          Text(
                            step.durationLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.inkSecondaryOf(brightness).withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: tile,
    );
  }
}

// ── Jeepney route sheet ─────────────────────────────────────────────────────

/// Bottom sheet for jeepney route details.
class JeepneyRouteSheet extends StatelessWidget {
  const JeepneyRouteSheet({super.key, required this.route, required this.onClose});

  final JeepneyRoute route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(route.colorHex);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // Add bottom inset so sheet content clears the nav bar
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperOf(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? AppColors.edgeDark.withValues(alpha: 0.6) : color.withValues(alpha: 0.3), width: 2),
          left: BorderSide(color: isDark ? AppColors.edgeDark.withValues(alpha: 0.4) : AppColors.hairline, width: 1.5),
          right: BorderSide(color: isDark ? AppColors.edgeDark.withValues(alpha: 0.4) : AppColors.hairline, width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.routeName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (route.operatingHours != null)
                      Text(route.operatingHours!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSecondaryOf(brightness),
                      )),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sunkenOf(brightness),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _InfoPill(
                icon: Icons.directions_bus_rounded,
                label: '${route.stops.length} stops',
                color: color,
              ),
              _InfoPill(
                icon: Icons.label_rounded,
                label: route.routeCode,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Stops', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          ...route.stops.map(
            (stop) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${stop.order}',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(stop.name, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

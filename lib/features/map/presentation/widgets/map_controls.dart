import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Floating glass-style map control buttons.
class MapGlassButton extends StatelessWidget {
  const MapGlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive
                    ? AppColors.secondary
                    : Colors.white.withValues(alpha: 0.3),
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.secondary : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Layer toggle panel for map overlays.
class MapLayerPanel extends StatelessWidget {
  const MapLayerPanel({
    super.key,
    required this.showJeepney,
    required this.showTricycle,
    required this.showStops,
    required this.showStopLabels,
    required this.showTransfers,
    required this.showTourist,
    required this.showEmergency,
    required this.onJeepneyChanged,
    required this.onTricycleChanged,
    required this.onStopsChanged,
    required this.onStopLabelsChanged,
    required this.onTransfersChanged,
    required this.onTouristChanged,
    required this.onEmergencyChanged,
    required this.onClose,
    this.showHighway = false,
    this.onHighwayChanged,
  });

  final bool showJeepney;
  final bool showTricycle;
  final bool showStops;
  final bool showStopLabels;
  final bool showTransfers;
  final bool showTourist;
  final bool showEmergency;
  final bool showHighway;
  final ValueChanged<bool> onJeepneyChanged;
  final ValueChanged<bool> onTricycleChanged;
  final ValueChanged<bool> onStopsChanged;
  final ValueChanged<bool> onStopLabelsChanged;
  final ValueChanged<bool> onTransfersChanged;
  final ValueChanged<bool> onTouristChanged;
  final ValueChanged<bool> onEmergencyChanged;
  final ValueChanged<bool>? onHighwayChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Map Layers', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jeepney Routes'),
              subtitle: const Text('Visible at zoom 14+'),
              value: showJeepney,
              onChanged: onJeepneyChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jeepney Stops'),
              subtitle: const Text('Visible at zoom 15.5+'),
              value: showStops,
              onChanged: onStopsChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stop Labels'),
              subtitle: const Text('Visible at zoom 16.5+'),
              value: showStopLabels,
              onChanged: onStopLabelsChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transfer Points'),
              value: showTransfers,
              onChanged: onTransfersChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tricycle Zones'),
              value: showTricycle,
              onChanged: onTricycleChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tourist & Places'),
              value: showTourist,
              onChanged: onTouristChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emergency Services'),
              value: showEmergency,
              onChanged: onEmergencyChanged,
            ),
            if (onHighwayChanged != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('National Highways'),
                subtitle: const Text('Tricycle restriction zones'),
                value: showHighway,
                onChanged: onHighwayChanged,
              ),
          ],
        ),
      ),
    );
  }
}

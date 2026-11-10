import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Floating glass-style map control buttons with blur backdrop.
class MapGlassButton extends StatefulWidget {
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
  State<MapGlassButton> createState() => _MapGlassButtonState();
}

class _MapGlassButtonState extends State<MapGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.reverse();
  void _onTapUp(TapUpDetails _) {
    _scaleController.forward();
    widget.onPressed();
  }
  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = AppColors.paperOf(isDark ? Brightness.dark : Brightness.light);
    final borderColor = widget.isActive
        ? AppColors.primaryFillOf(isDark ? Brightness.dark : Brightness.light)
        : (isDark ? AppColors.edgeDark : AppColors.edgeOf(Brightness.light));
    final iconColor = widget.isActive
        ? AppColors.primaryFillOf(isDark ? Brightness.dark : Brightness.light)
        : AppColors.inkOf(isDark ? Brightness.dark : Brightness.light);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: paperColor.withValues(alpha: isDark ? 0.82 : 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, size: 22, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layer toggle panel for map overlays — frosted glass card.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = AppColors.paperOf(isDark ? Brightness.dark : Brightness.light);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: paperColor.withValues(alpha: isDark ? 0.88 : 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? AppColors.edgeDark : AppColors.edge)
                  .withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Map Layers', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.sunkenOf(isDark ? Brightness.dark : Brightness.light),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _LayerToggle(
                  icon: Icons.directions_bus_rounded,
                  title: 'Jeepney Routes',
                  subtitle: 'Visible at zoom 14+',
                  value: showJeepney,
                  onChanged: onJeepneyChanged,
                  color: AppColors.primary,
                ),
                _LayerToggle(
                  icon: Icons.stop_circle_outlined,
                  title: 'Jeepney Stops',
                  subtitle: 'Visible at zoom 15.5+',
                  value: showStops,
                  onChanged: onStopsChanged,
                  color: AppColors.primary,
                ),
                _LayerToggle(
                  icon: Icons.label_rounded,
                  title: 'Stop Labels',
                  subtitle: 'Visible at zoom 16.5+',
                  value: showStopLabels,
                  onChanged: onStopLabelsChanged,
                  color: AppColors.secondary,
                ),
                _LayerToggle(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transfer Points',
                  value: showTransfers,
                  onChanged: onTransfersChanged,
                  color: AppColors.accent,
                ),
                _LayerToggle(
                  icon: Icons.moped_rounded,
                  title: 'Tricycle Zones',
                  value: showTricycle,
                  onChanged: onTricycleChanged,
                  color: AppColors.warning,
                ),
                _LayerToggle(
                  icon: Icons.attractions_rounded,
                  title: 'Tourist & Places',
                  value: showTourist,
                  onChanged: onTouristChanged,
                  color: AppColors.catAttraction,
                ),
                _LayerToggle(
                  icon: Icons.emergency_rounded,
                  title: 'Emergency Services',
                  value: showEmergency,
                  onChanged: onEmergencyChanged,
                  color: AppColors.danger,
                ),
                if (onHighwayChanged != null)
                  _LayerToggle(
                    icon: Icons.do_not_disturb_on_outlined,
                    title: 'National Highways',
                    subtitle: 'Tricycle restriction zones',
                    value: showHighway,
                    onChanged: onHighwayChanged!,
                    color: AppColors.danger,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: value
                  ? color.withValues(alpha: 0.15)
                  : AppColors.sunkenOf(isDark ? Brightness.dark : Brightness.light),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: value ? color : AppColors.inkSecondaryOf(isDark ? Brightness.dark : Brightness.light)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.inkSecondaryOf(isDark ? Brightness.dark : Brightness.light),
                  )),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

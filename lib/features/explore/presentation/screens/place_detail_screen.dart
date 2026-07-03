import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/error_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/core/widgets/primary_button.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_notifier.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Detailed view for a tourist attraction or establishment.
class PlaceDetailScreen extends ConsumerStatefulWidget {
  const PlaceDetailScreen({
    super.key,
    required this.placeType,
    required this.placeId,
  });

  final String placeType;
  final int placeId;

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  Place? _place;
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(placesRepositoryProvider);
      final place = widget.placeType == 'attraction'
          ? await repo.getAttraction(widget.placeId)
          : await repo.getEstablishment(widget.placeId);
      final fav = await ref.read(favoritesNotifierProvider.notifier).isFavorite(place);
      if (!mounted) return;
      setState(() {
        _place = place;
        _isFavorite = fav;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final place = _place;
    if (place == null) return;
    final added = await ref.read(favoritesNotifierProvider.notifier).toggleFavorite(place);
    if (!mounted) return;
    setState(() => _isFavorite = added);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(added ? 'Saved to favorites' : 'Removed from favorites')),
    );
  }

  Future<void> _planTrip() async {
    final place = _place;
    if (place == null || !place.hasVerifiedCoordinates) return;
    await ref.read(mapNotifierProvider.notifier).planTripTo(
          MapLocation.fromLatLng(place.latLng, label: place.name),
        );
    if (!mounted) return;
    context.go(AppRoutes.map);
  }

  void _navigateOnMap() {
    final place = _place;
    if (place == null) return;
    ref.read(mapNotifierProvider.notifier).selectDestination(
          MapLocation.fromLatLng(place.latLng, label: place.name),
        );
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingOverlay(message: 'Loading details...'));
    }
    if (_error != null || _place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(message: _error ?? 'Place not found', onRetry: _load),
      );
    }

    final place = _place!;
    final color = PlaceUtils.colorForCategory(place.category);
    final icon = PlaceUtils.iconForCategory(place.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
              ),
            ),
            child: Center(child: Icon(icon, size: 72, color: Colors.white)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Chip(
            avatar: Icon(icon, size: 16, color: color),
            label: Text(PlaceUtils.labelForCategory(place.category)),
          ),
          if (place.description != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(place.description!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (place.address != null) _InfoRow(icon: Icons.place_outlined, label: place.address!),
          if (place.openingHours != null)
            _InfoRow(icon: Icons.schedule_rounded, label: place.openingHours!),
          if (place.entranceFee != null)
            _InfoRow(icon: Icons.payments_outlined, label: place.entranceFee!),
          if (place.contactInformation != null)
            _InfoRow(icon: Icons.phone_outlined, label: place.contactInformation!),
          const SizedBox(height: AppSpacing.xl),
          if (place.hasVerifiedCoordinates)
            PrimaryButton(
              label: 'Plan a trip here',
              icon: Icons.directions_rounded,
              onPressed: _planTrip,
            ),
          if (place.hasVerifiedCoordinates) const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'View on Map', icon: Icons.map_rounded, onPressed: _navigateOnMap),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

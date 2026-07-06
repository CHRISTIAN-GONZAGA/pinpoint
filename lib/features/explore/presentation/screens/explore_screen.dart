import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/error_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/core/widgets/place_card.dart';
import 'package:pinpoint/core/widgets/premium_surface.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Tourism and nearby places exploration screen.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  Future<void> _planTripTo(Place place) async {
    if (!place.hasVerifiedCoordinates) return;
    await ref.read(mapNotifierProvider.notifier).planTripTo(
          MapLocation.fromLatLng(place.latLng, label: place.name),
        );
    if (!mounted) return;
    context.go(AppRoutes.map);
  }

  Widget _planTripTrailing(Place place) {
    if (!place.hasVerifiedCoordinates) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Plan a trip',
      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
      onPressed: () => _planTripTo(place),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(exploreNotifierProvider.notifier).initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreNotifierProvider);

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: state.isLoading
          ? const LoadingOverlay(message: 'Loading places...')
          : state.errorMessage != null && state.attractions.isEmpty
              ? ErrorStateWidget(
                  message: state.errorMessage!,
                  onRetry: () => ref.read(exploreNotifierProvider.notifier).initialize(),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(exploreNotifierProvider.notifier).initialize(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      PremiumSectionHeader(
                        title: 'Explore',
                        subtitle: 'Discover places across Butuan City.',
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => context.push(AppRoutes.emergency),
                          icon: const Icon(Icons.emergency_outlined, size: 22),
                        ),
                      ),
                      TextField(
                        controller: _searchController,
                        onChanged: (q) =>
                            ref.read(exploreNotifierProvider.notifier).search(q),
                        decoration: InputDecoration(
                          hintText: 'Search attractions, food, services…',
                          prefixIcon: const Icon(Icons.search_rounded, size: 22),
                          suffixIcon: state.isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(exploreNotifierProvider.notifier).search('');
                                  },
                                ),
                        ),
                      ),
                      if (state.searchResults.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const PremiumSectionLabel('Results'),
                        const SizedBox(height: 8),
                        ...state.searchResults.map(
                          (place) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PlaceCard(
                              place: place,
                              onTap: () => context.push(
                                AppRoutes.placeDetail(place.placeType, place.id),
                              ),
                              trailing: _planTripTrailing(place),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      const PremiumSectionLabel('Categories'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: PlaceUtils.categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final cat = PlaceUtils.categories[index];
                            final icon = PlaceUtils.iconForCategory(cat.apiCategory);
                            return PremiumActionTile(
                              icon: icon,
                              label: cat.label,
                              onTap: () => context.push(AppRoutes.category(cat.id)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      const PremiumSectionLabel('Nearby'),
                      const SizedBox(height: 10),
                      if (state.nearbyPlaces.isEmpty && state.attractions.isEmpty)
                        const EmptyStateWidget(
                          icon: Icons.near_me_outlined,
                          title: 'No nearby places',
                          message: 'Enable location or browse categories above.',
                        )
                      else if (state.nearbyPlaces.isEmpty)
                        ...state.attractions.take(6).map(
                              (place) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PlaceCard(
                                  place: place,
                                  onTap: () => context.push(
                                    AppRoutes.placeDetail(place.placeType, place.id),
                                  ),
                                  trailing: _planTripTrailing(place),
                                ),
                              ),
                            )
                      else
                        ...state.nearbyPlaces.take(6).map(
                              (place) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PlaceCard(
                                  place: place,
                                  onTap: () => context.push(
                                    AppRoutes.placeDetail(place.placeType, place.id),
                                  ),
                                  trailing: _planTripTrailing(place),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }
}

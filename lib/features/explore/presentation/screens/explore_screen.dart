import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/error_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/core/widgets/place_card.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';

/// Tourism and nearby places exploration screen.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

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
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency_rounded),
            onPressed: () => context.push(AppRoutes.emergency),
          ),
        ],
      ),
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
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    children: [
                      Text('Discover Butuan', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Browse tourist attractions and nearby establishments.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _searchController,
                        onChanged: (q) =>
                            ref.read(exploreNotifierProvider.notifier).search(q),
                        decoration: InputDecoration(
                          hintText: 'Search attractions, restaurants...',
                          prefixIcon: const Icon(Icons.search_rounded),
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
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(exploreNotifierProvider.notifier).search('');
                                  },
                                ),
                        ),
                      ),
                      if (state.searchResults.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Search Results', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        ...state.searchResults.map(
                          (place) => PlaceCard(
                            place: place,
                            onTap: () => context.push(
                              AppRoutes.placeDetail(place.placeType, place.id),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text('Categories', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: PlaceUtils.categories.length,
                        itemBuilder: (context, index) {
                          final cat = PlaceUtils.categories[index];
                          final icon = PlaceUtils.iconForCategory(cat.apiCategory);
                          final color = PlaceUtils.colorForCategory(cat.apiCategory);
                          return Card(
                            child: InkWell(
                              onTap: () => context.push(AppRoutes.category(cat.id)),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 36, color: color),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(cat.label, style: Theme.of(context).textTheme.titleSmall),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Nearby Highlights', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      if (state.nearbyPlaces.isEmpty && state.attractions.isEmpty)
                        const EmptyStateWidget(
                          icon: Icons.near_me_outlined,
                          title: 'No nearby places',
                          message: 'Enable GPS or browse categories below.',
                        )
                      else if (state.nearbyPlaces.isEmpty)
                        ...state.attractions.take(6).map(
                              (place) => PlaceCard(
                                place: place,
                                onTap: () => context.push(
                                  AppRoutes.placeDetail(place.placeType, place.id),
                                ),
                              ),
                            )
                      else
                        ...state.nearbyPlaces.take(6).map(
                              (place) => PlaceCard(
                                place: place,
                                onTap: () => context.push(
                                  AppRoutes.placeDetail(place.placeType, place.id),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }
}

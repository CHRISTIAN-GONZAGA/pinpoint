import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_notifier.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Curated favorites — premium list, not stock Material cards.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(favoritesNotifierProvider.notifier).load());
  }

  Future<void> _goToFavorite(FavoriteItem item) async {
    if (item.latitude != null && item.longitude != null) {
      await ref.read(mapNotifierProvider.notifier).planTripTo(
            MapLocation(
              latitude: item.latitude!,
              longitude: item.longitude!,
              label: item.label,
            ),
          );
      if (mounted) context.go(AppRoutes.map);
      return;
    }
    if (item.placeId != null) {
      context.push(AppRoutes.placeDetail(item.placeType, item.placeId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesNotifierProvider);
    final isGuest = ref.watch(authNotifierProvider).isGuest;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorites',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Places you return to',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PremiumTokens.inkMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    Text(
                      '${state.items.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppSpacing.screenMargin),
                      children: List.generate(
                        4,
                        (i) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: LoadingShimmer(height: 78, borderRadius: 16),
                        ),
                      ),
                    )
                  : state.items.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.bookmark_border_rounded,
                          title: 'Nothing saved yet',
                          message: isGuest
                              ? 'Bookmark places as you explore — sign in later to sync.'
                              : 'Tap the bookmark on any place to keep it here.',
                          actionLabel: isGuest ? 'Sign in' : 'Explore places',
                          onAction: () => context.go(
                            isGuest ? AppRoutes.login : AppRoutes.explore,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(favoritesNotifierProvider.notifier).load(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            itemCount: state.items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              final accent = PlaceUtils.colorForCategory(item.category);
                              return _FavoriteRow(
                                item: item,
                                accent: accent,
                                onOpen: () => _goToFavorite(item),
                                onRemove: () => ref
                                    .read(favoritesNotifierProvider.notifier)
                                    .remove(item),
                              )
                                  .animate(delay: (40 * index).ms)
                                  .fadeIn(duration: 280.ms)
                                  .slideY(begin: 0.04, end: 0);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.item,
    required this.accent,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteItem item;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: PremiumTokens.elevatedSurface(context),
      borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
            border: Border.all(color: PremiumTokens.separator(context)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    PlaceUtils.iconForCategory(item.category),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          PlaceUtils.labelForCategory(item.category),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: PremiumTokens.inkMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Go'),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

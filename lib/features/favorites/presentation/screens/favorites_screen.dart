import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_notifier.dart';

/// Saved favorites screen.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesNotifierProvider);
    final isGuest = ref.watch(authNotifierProvider).isGuest;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: state.isLoading
          ? const LoadingOverlay(message: 'Loading favorites...')
          : state.items.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorites yet',
                  message: isGuest
                      ? 'Save places locally as a guest, or sign in to sync across devices.'
                      : 'Tap the heart icon on any place to save it here.',
                  actionLabel: isGuest ? 'Sign In' : null,
                  onAction: isGuest ? () => context.go(AppRoutes.login) : null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ListTile(
                        leading: const Icon(Icons.favorite_rounded, color: Colors.red),
                        title: Text(item.label),
                        subtitle: Text(PlaceUtils.labelForCategory(item.category)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(favoritesNotifierProvider.notifier).remove(item),
                        ),
                        onTap: () {
                          if (item.placeId != null) {
                            context.push(
                              AppRoutes.placeDetail(item.placeType, item.placeId!),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

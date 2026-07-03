import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';
import 'package:pinpoint/core/widgets/place_card.dart';

/// Main bottom navigation shell with five primary tabs.
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: navigationShell.currentIndex == 3 ||
              navigationShell.currentIndex == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => navigationShell.goBranch(3),
              icon: const Icon(Icons.smart_toy_rounded),
              label: const Text('AI'),
            ),
    );
  }
}

/// Personalized home dashboard with quick actions and nearby highlights.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      unawaited(ref.read(mapNotifierProvider.notifier).refreshLocation());
      await ref.read(exploreNotifierProvider.notifier).initialize();
      await ref.read(notificationsNotifierProvider.notifier).loadAnnouncements();
      final user = ref.read(currentUserProvider);
      if (user != null && !user.isGuest) {
        await ref.read(notificationsNotifierProvider.notifier).loadNotifications();
      }
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final name = user != null && !user.isGuest ? ', ${user.firstName}' : '';
    final announcements = ref.watch(notificationsNotifierProvider).announcements;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting$name')
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.05, end: 0),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Welcome to ${AppConstants.cityName}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (announcements.isNotEmpty) ...[
                      _AnnouncementsBanner(announcements: announcements.take(3).toList()),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    const _LocationCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _SearchBar().animate(delay: 150.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    const _QuickActionsGrid(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Nearby Highlights', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    const _NearbyList(),
                    const SizedBox(height: AppSpacing.xl),
                    _EmergencyBanner().animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsBanner extends StatelessWidget {
  const _AnnouncementsBanner({required this.announcements});

  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    final item = announcements.first;
    return Card(
      color: item.isHighPriority
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.campaign_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final address = mapState.currentAddress ?? AppConstants.cityName;
    final accuracy = mapState.currentLocation?.accuracyMeters;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: mapState.isLocating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Location', style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    address,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    mapState.locationWarning ??
                        (accuracy != null
                            ? 'GPS accuracy: ${accuracy.round()} m'
                            : 'Tap refresh to detect your location'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mapState.locationWarning != null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: mapState.isLocating
                  ? null
                  : () => ref.read(mapNotifierProvider.notifier).refreshLocation(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: InkWell(
        onTap: () => context.go(AppRoutes.map),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Where do you want to go?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ),
              Icon(Icons.mic_rounded, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const _actions = [
    (Icons.route_rounded, 'Plan Route', AppRoutes.map, AppColors.primary),
    (Icons.near_me_rounded, 'Explore Nearby', AppRoutes.explore, AppColors.accent),
    (Icons.smart_toy_rounded, 'AI Assistant', AppRoutes.ai, AppColors.secondary),
    (Icons.emergency_rounded, 'Emergency', AppRoutes.emergency, AppColors.danger),
    (Icons.favorite_rounded, 'Favorites', AppRoutes.favorites, AppColors.warning),
    (Icons.history_rounded, 'History', AppRoutes.history, Color(0xFF6366F1)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.6,
      ),
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        final (icon, label, route, color) = _actions[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const Spacer(),
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
          ),
        )
            .animate(delay: (index * 50).ms)
            .fadeIn()
            .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
      },
    );
  }
}

class _NearbyList extends ConsumerWidget {
  const _NearbyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(exploreNotifierProvider).nearbyPlaces;
    if (nearby.isEmpty) {
      return const Text('Enable location to see nearby highlights.');
    }
    return Column(
      children: nearby.take(5).map((place) {
        return PlaceCard(
          place: place,
          onTap: () => context.push(AppRoutes.placeDetail(place.placeType, place.id)),
        );
      }).toList(),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.emergencyGradient,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                Text(
                  'Quick access to hospitals, police & hotlines',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.emergency),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

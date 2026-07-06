import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/widgets/home_greeting_header.dart';
import 'package:pinpoint/core/widgets/place_card.dart';
import 'package:pinpoint/core/widgets/premium_surface.dart';
import 'package:pinpoint/shared/widgets/destination_search_field.dart';

/// Main bottom navigation shell with five primary tabs.
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(navigationShell.currentIndex),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PremiumTokens.navBarRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PremiumTokens.navBarRadius),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                if (index != navigationShell.currentIndex) {
                  navigationShell.goBranch(index);
                }
              },
              animationDuration: const Duration(milliseconds: 320),
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
                  icon: Icon(Icons.bubble_chart_outlined),
                  selectedIcon: Icon(Icons.bubble_chart_rounded),
                  label: 'Assistant',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
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
      unawaited(ref.read(mapNotifierProvider.notifier).initialize());
      unawaited(ref.read(mapNotifierProvider.notifier).refreshLocation());
      await ref.read(exploreNotifierProvider.notifier).initialize();
      await ref.read(notificationsNotifierProvider.notifier).loadAnnouncements();
      final user = ref.read(currentUserProvider);
      if (user != null && !user.isGuest) {
        await ref.read(notificationsNotifierProvider.notifier).loadNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final announcements = ref.watch(notificationsNotifierProvider).announcements;

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeGreetingHeader(user: user),
                    const SizedBox(height: 24),
                    const _HomeSearchBar(),
                    const SizedBox(height: 20),
                    if (announcements.isNotEmpty) ...[
                      _AnnouncementsBanner(announcements: announcements.take(3).toList()),
                      const SizedBox(height: 20),
                    ],
                    const _LocationCard(),
                    const SizedBox(height: 28),
                    const PremiumSectionLabel('Go somewhere'),
                    const SizedBox(height: 10),
                    const _QuickActionsRow(),
                    const SizedBox(height: 28),
                    const PremiumSectionLabel('Popular places'),
                    const SizedBox(height: 10),
                    const _FeaturedDestinationChips(),
                    const SizedBox(height: 28),
                    const PremiumSectionLabel('Nearby'),
                    const SizedBox(height: 10),
                    const _NearbyList(),
                    const SizedBox(height: 20),
                    _EmergencyBanner(),
                    const SizedBox(height: 100),
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
    final theme = Theme.of(context);
    return PremiumSurface(
      children: [
        PremiumListRow(
          dense: true,
          leading: Icon(
            Icons.info_outline_rounded,
            color: item.isHighPriority ? theme.colorScheme.error : theme.colorScheme.primary,
            size: 22,
          ),
          title: item.title,
          subtitle: item.content,
        ),
      ],
    );
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final address = mapState.currentAddress ?? AppConstants.cityName;

    return PremiumSurface(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PremiumTokens.subtleFill(context),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: mapState.isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.near_me_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are here',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: mapState.isLocating
                    ? null
                    : () => ref.read(mapNotifierProvider.notifier).refreshLocation(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    ).animate(delay: 80.ms).fadeIn();
  }
}

class _HomeSearchBar extends ConsumerWidget {
  const _HomeSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    return DestinationSearchField(
      hintText: 'Where do you want to go?',
      isSearching: mapState.isSearching,
      results: mapState.searchResults,
      onQueryChanged: (q) => ref.read(mapNotifierProvider.notifier).searchPlaces(q),
      onSelect: (loc) async {
        await ref.read(mapNotifierProvider.notifier).planTripTo(loc);
        if (context.mounted) context.go(AppRoutes.map);
      },
    );
  }
}

class _FeaturedDestinationChips extends ConsumerWidget {
  const _FeaturedDestinationChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(mapNotifierProvider).featuredDestinations;
    if (featured.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = featured[index];
          return PremiumActionTile(
            icon: Icons.place_outlined,
            label: item.shortLabel,
            accent: Theme.of(context).colorScheme.secondary,
            onTap: () async {
              await ref.read(mapNotifierProvider.notifier).planTripTo(
                    MapLocation(
                      latitude: item.place.latitude,
                      longitude: item.place.longitude,
                      label: item.place.name,
                    ),
                  );
              if (context.mounted) context.go(AppRoutes.map);
            },
          );
        },
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  static const _actions = [
    (Icons.route_rounded, 'Plan route', AppRoutes.map),
    (Icons.explore_outlined, 'Explore', AppRoutes.explore),
    (Icons.bubble_chart_outlined, 'Assistant', AppRoutes.ai),
    (Icons.emergency_outlined, 'Emergency', AppRoutes.emergency),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (icon, label, route) = _actions[index];
          return PremiumActionTile(
            icon: icon,
            label: label,
            onTap: () => context.push(route),
          );
        },
      ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PlaceCard(
            place: place,
            onTap: () => context.push(AppRoutes.placeDetail(place.placeType, place.id)),
          ),
        );
      }).toList(),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumSurface(
      children: [
        PremiumListRow(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.emergency_outlined, color: Color(0xFFFF3B30), size: 20),
          ),
          title: 'Emergency',
          subtitle: 'Hospitals, police, and hotlines',
          onTap: () => context.push(AppRoutes.emergency),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

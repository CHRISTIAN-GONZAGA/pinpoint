import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_notifier.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/history/presentation/viewmodels/history_notifier.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:intl/intl.dart';
import 'package:pinpoint/core/design_system/plates.dart';
import 'package:pinpoint/core/design_system/ticket_card.dart';
import 'package:pinpoint/core/widgets/home_greeting_header.dart';
import 'package:pinpoint/core/widgets/place_card.dart';
import 'package:pinpoint/core/widgets/premium_surface.dart';
import 'package:pinpoint/shared/widgets/destination_search_field.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _DockBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) {
          if (index == 0 || index == 1) {
            unawaited(
              ref.read(mapNotifierProvider.notifier).refreshFeaturedDestinations(),
            );
          }
          if (index != navigationShell.currentIndex) {
            navigationShell.goBranch(index);
          }
        },
      ),
    );
  }
}

class _DockBar extends StatelessWidget {
  const _DockBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.map_outlined, 'Map'),
    (Icons.explore_outlined, 'Explore'),
    (Icons.chat_bubble_outline, 'Assistant'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.paperOf(brightness),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.edgeOf(brightness), width: 2)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: _DockItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        selected: i == currentIndex,
                      ),
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

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = selected
        ? AppColors.inkOf(brightness)
        : AppColors.inkSecondaryOf(brightness);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (selected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.56,
                child: Container(
                  height: 4,
                  color: brightness == Brightness.dark
                      ? AppColors.primaryText
                      : AppColors.primary,
                ),
              ),
            ),
          ),
        Column(
          children: [
            const SizedBox(height: 8),
            const Spacer(),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
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
      unawaited(ref.read(favoritesNotifierProvider.notifier).load());
      unawaited(ref.read(historyNotifierProvider.notifier).load());
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
    final announcements = ref.watch(
      notificationsNotifierProvider.select((s) => s.announcements),
    );
    final featured = ref.watch(
      mapNotifierProvider.select((s) => s.featuredDestinations),
    );
    final nearby = ref.watch(
      exploreNotifierProvider.select((s) => s.nearbyPlaces),
    );

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(mapNotifierProvider.notifier).initialize(),
              ref.read(mapNotifierProvider.notifier).refreshLocation(),
              ref.read(mapNotifierProvider.notifier).refreshFeaturedDestinations(force: true),
              ref.read(exploreNotifierProvider.notifier).initialize(),
              ref.read(notificationsNotifierProvider.notifier).loadAnnouncements(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeTop(user: user),
                      const SizedBox(height: 24),
                      Text(
                        _todayLabel(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Where to today?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 52),
                      ),
                      const SizedBox(height: 16),
                      const _HomeSearchBar(),
                      const SizedBox(height: 14),
                      _FareNotice(announcements: announcements),
                      const SizedBox(height: 16),
                      const _ActionGrid(),
                      const SizedBox(height: 26),
                      HomeSectionHeader(
                        title: 'Popular destinations',
                      ),
                      if (featured.isEmpty)
                        HomeEmptyHint(
                          icon: Icons.place_outlined,
                          title: 'Destinations loading',
                          message: 'Pull to refresh, or open Map to browse places.',
                          actionLabel: 'Open map',
                          onAction: () => context.go(AppRoutes.map),
                        )
                      else
                        const _PopularNowRail(),
                      const SizedBox(height: 26),
                      HomeSectionHeader(
                        title: 'Around you',
                        subtitle: 'Places near your current spot',
                        actionLabel: nearby.isEmpty ? null : 'Explore',
                        onAction: nearby.isEmpty ? null : () => context.go(AppRoutes.explore),
                      ),
                      const _NearbyList(),
                      const SizedBox(height: 12),
                      _EmergencyBanner(),
                      const SizedBox(height: 18),
                      const _SavedAndRecentSection(),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _todayLabel() => DateFormat('EEEE, MMMM d').format(DateTime.now());

class _HomeTop extends StatelessWidget {
  const _HomeTop({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = (user?.fullName as String?)?.trim();
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'B';
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.sunkenOf(brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 18, color: brightness == Brightness.dark ? AppColors.primaryText : AppColors.primary),
              const SizedBox(width: 6),
              const Text('Butuan City', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go(AppRoutes.profile),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.signal,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.edgeOf(brightness), width: 2),
            ),
            child: Text(
              initial,
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _FareNotice extends StatelessWidget {
  const _FareNotice({required this.announcements});

  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    final item = announcements.isEmpty ? null : announcements.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paperOf(Theme.of(context).brightness),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
          bottomLeft: Radius.circular(4),
        ),
        border: const Border(left: BorderSide(color: AppColors.signal, width: 6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item?.title ?? 'Fares follow the city fare matrix',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              item?.content ??
                  'Jeepney and tricycle prices come from the latest matrix the administrator published.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 13,
          child: Material(
            color: AppColors.primaryFillOf(brightness),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
            child: InkWell(
              onTap: () => context.go(AppRoutes.map),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(6),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.route, color: Colors.white, size: 30),
                    SizedBox(height: 18),
                    Text(
                      'Plan a trip',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Find the jeep, the fare and where to get off',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: Column(
            children: [
              PlateCard(
                onTap: () => context.go(AppRoutes.ai),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 22),
                    SizedBox(height: 8),
                    Text(
                      'Ask the\nassistant',
                      softWrap: true,
                      style: TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PlateCard(
                onTap: () => context.push(AppRoutes.emergency),
                borderColor: brightness == Brightness.dark
                    ? AppColors.dangerTextDark
                    : AppColors.dangerText,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 22,
                      color: brightness == Brightness.dark
                          ? AppColors.dangerTextDark
                          : AppColors.dangerText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Emergency\nhelp',
                      softWrap: true,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: brightness == Brightness.dark
                            ? AppColors.dangerTextDark
                            : AppColors.dangerText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _HomeSearchBar extends ConsumerWidget {
  const _HomeSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearching = ref.watch(mapNotifierProvider.select((s) => s.isSearching));
    final results = ref.watch(mapNotifierProvider.select((s) => s.searchResults));
    return DestinationSearchField(
      hintText: 'Search a place in Butuan',
      isSearching: isSearching,
      results: results,
      onQueryChanged: (q) => ref.read(mapNotifierProvider.notifier).searchPlaces(q),
      onSelect: (loc) async {
        await ref.read(mapNotifierProvider.notifier).planTripTo(loc);
        if (context.mounted) context.go(AppRoutes.map);
      },
    );
  }
}

class _PopularNowRail extends ConsumerWidget {
  const _PopularNowRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(mapNotifierProvider.select((s) => s.featuredDestinations));
    if (featured.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = featured[index];
          final categoryLabel =
              CommonDestinations.destinationCategories[item.place.category] ??
                  PlaceUtils.labelForCategory(item.place.category);
          final title = item.shortLabel.trim().isEmpty ? item.place.name : item.shortLabel;

          return TicketCard(
            title: title,
            category: categoryLabel,
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


class _SavedAndRecentSection extends ConsumerWidget {
  const _SavedAndRecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesNotifierProvider.select((s) => s.items));
    final history = ref.watch(historyNotifierProvider).items;
    if (favorites.isEmpty && history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Saved & recent',
          subtitle: 'Your bookmarks and last searches',
          actionLabel: 'See all',
          onAction: () => context.push(
            favorites.isNotEmpty ? AppRoutes.favorites : AppRoutes.history,
          ),
        ),
        if (favorites.isNotEmpty) ...[
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = favorites[index];
                final accent = PlaceUtils.colorForCategory(item.category);
                return ActionChip(
                  avatar: Icon(
                    PlaceUtils.iconForCategory(item.category),
                    size: 16,
                    color: accent,
                  ),
                  label: Text(item.label),
                  backgroundColor: PremiumTokens.elevatedSurface(context),
                  side: BorderSide(color: PremiumTokens.separator(context)),
                  onPressed: () async {
                    if (item.latitude != null && item.longitude != null) {
                      await ref.read(mapNotifierProvider.notifier).planTripTo(
                            MapLocation(
                              latitude: item.latitude!,
                              longitude: item.longitude!,
                              label: item.label,
                            ),
                          );
                      if (context.mounted) context.go(AppRoutes.map);
                    } else if (item.placeId != null) {
                      context.push(
                        AppRoutes.placeDetail(item.placeType, item.placeId!),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (history.isNotEmpty)
          PremiumSurface(
            children: history.take(3).map((item) {
              return PremiumListRow(
                dense: true,
                leading: Icon(
                  item.searchType == 'route'
                      ? Icons.route_rounded
                      : Icons.history_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                title: item.query,
                subtitle: item.searchType == 'route' ? 'Route' : 'Search',
                onTap: () async {
                  if (item.latitude != null && item.longitude != null) {
                    await ref.read(mapNotifierProvider.notifier).planTripTo(
                          MapLocation(
                            latitude: item.latitude!,
                            longitude: item.longitude!,
                            label: item.query,
                          ),
                        );
                  } else {
                    await ref.read(mapNotifierProvider.notifier).searchPlaces(item.query);
                  }
                  if (context.mounted) context.go(AppRoutes.map);
                },
                trailing: Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _NearbyList extends ConsumerWidget {
  const _NearbyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(exploreNotifierProvider.select((s) => s.nearbyPlaces));
    final favorites = ref.watch(favoritesNotifierProvider.select((s) => s.items));
    if (nearby.isEmpty) {
      final locating = ref.watch(mapNotifierProvider.select((s) => s.currentLocation)) == null;
      return HomeEmptyHint(
        icon: Icons.location_searching_rounded,
        title: locating ? 'Location is off' : 'No places nearby yet',
        message: locating
            ? 'Turn on location to see hospitals, malls, and spots around you.'
            : 'Pull to refresh, or open Explore to browse places.',
        actionLabel: locating ? 'Turn on location' : 'Retry',
        onAction: () {
          ref.read(mapNotifierProvider.notifier).refreshLocation();
          ref.read(exploreNotifierProvider.notifier).initialize();
        },
      );
    }
    return Column(
      children: nearby.take(5).map((place) {
        final saved = favorites.any(
          (f) => f.placeType == place.placeType && f.placeId == place.id,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PlaceCard(
            place: place,
            isFavorite: saved,
            onFavorite: () =>
                ref.read(favoritesNotifierProvider.notifier).toggleFavorite(place),
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
    final danger = AppColors.dangerOf(theme.brightness);
    return PremiumSurface(
      children: [
        PremiumListRow(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.emergency_outlined, color: danger, size: 20),
          ),
          title: 'Need help fast?',
          subtitle: 'Hospitals, police, fire, and hotlines in one tap',
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

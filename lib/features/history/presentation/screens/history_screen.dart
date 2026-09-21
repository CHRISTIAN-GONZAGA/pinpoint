import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/history/presentation/viewmodels/history_notifier.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Search & trip history — actionable, premium timeline.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(historyNotifierProvider.notifier).load());
  }

  Future<void> _openItem(HistoryItem item) async {
    if (item.latitude != null && item.longitude != null) {
      await ref.read(mapNotifierProvider.notifier).planTripTo(
            MapLocation(
              latitude: item.latitude!,
              longitude: item.longitude!,
              label: item.query,
            ),
          );
      if (mounted) context.go(AppRoutes.map);
      return;
    }
    await ref.read(mapNotifierProvider.notifier).searchPlaces(item.query);
    if (mounted) context.go(AppRoutes.map);
  }

  String _relativeTime(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(at);
  }

  String _typeLabel(String type) => switch (type) {
        'route' => 'Route',
        'place' => 'Place',
        'search' => 'Search',
        _ => type.isEmpty ? 'Search' : '${type[0].toUpperCase()}${type.substring(1)}',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
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
                          'History',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Recent searches and trips',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PremiumTokens.inkMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear history?'),
                            content: const Text(
                              'This removes your recent searches from this device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(historyNotifierProvider.notifier).clearAll();
                        }
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppSpacing.screenMargin),
                      children: List.generate(
                        5,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: LoadingShimmer(height: 72, borderRadius: 16),
                        ),
                      ),
                    )
                  : state.items.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.schedule_rounded,
                          title: 'No recent activity',
                          message: 'Searches and planned trips will show up here.',
                          actionLabel: 'Plan a trip',
                          onAction: () => context.go(AppRoutes.map),
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(historyNotifierProvider.notifier).load(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            itemCount: state.items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              final isRoute = item.searchType == 'route';
                              return Material(
                                color: PremiumTokens.elevatedSurface(context),
                                borderRadius:
                                    BorderRadius.circular(PremiumTokens.surfaceRadius),
                                child: InkWell(
                                  onTap: () => _openItem(item),
                                  borderRadius:
                                      BorderRadius.circular(PremiumTokens.surfaceRadius),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        PremiumTokens.surfaceRadius,
                                      ),
                                      border: Border.all(
                                        color: PremiumTokens.separator(context),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: (isRoute
                                                    ? AppColors.secondary
                                                    : AppColors.primary)
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: Icon(
                                            isRoute
                                                ? Icons.route_rounded
                                                : Icons.search_rounded,
                                            size: 20,
                                            color: isRoute
                                                ? AppColors.secondary
                                                : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.query,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                [
                                                  _typeLabel(item.searchType),
                                                  if (_relativeTime(item.createdAt)
                                                      .isNotEmpty)
                                                    _relativeTime(item.createdAt),
                                                ].join(' · '),
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: PremiumTokens.inkMuted(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: () => ref
                                              .read(historyNotifierProvider.notifier)
                                              .remove(item),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  .animate(delay: (30 * index).ms)
                                  .fadeIn(duration: 260.ms);
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

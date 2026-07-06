import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/core/localization/pinpoint_localizations.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/widgets/premium_surface.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User profile and settings screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _versionTapCount = 0;
  bool _developerModeEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDeveloperMode);
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      if (user != null && !user.isGuest) {
        ref.read(notificationsNotifierProvider.notifier).loadNotifications();
      }
    });
  }

  Future<void> _loadDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _developerModeEnabled = prefs.getBool(AppConstants.developerModeKey) ?? false;
    });
  }

  Future<void> _onVersionTap() async {
    if (!AppConstants.offlineFirstMode) return;
    _versionTapCount += 1;
    if (_versionTapCount < 7) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.developerModeKey, true);
    if (!mounted) return;
    setState(() => _developerModeEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Developer mode enabled')),
    );
  }

  bool _isLocalUser(String? userId) => userId == 'local';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final language = ref.watch(accessibilityNotifierProvider).languageCode;
    final offline = AppConstants.offlineFirstMode;
    final isGuest = user?.isGuest ?? true;
    final isLocal = _isLocalUser(user?.id);
    String t(String key) => PinpointLocalizations.t(key, language);

    return Scaffold(
      backgroundColor: PremiumTokens.groupedBackground(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          PremiumSectionHeader(title: t('profile')),
          PremiumSurface(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Guest',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGuest && !offline
                                ? 'Sign in to sync across devices'
                                : isLocal
                                    ? 'Local profile on this device'
                                    : user?.email ?? 'Butuan City traveler',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.45),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionLabel('Appearance'),
          PremiumSurface(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto, size: 18)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (modes) {
                    ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionLabel('Your data'),
          PremiumSurface(
            children: [
              PremiumListRow(
                title: 'Favorites',
                subtitle: isGuest && !offline ? 'Sign in to sync' : 'Saved places',
                leading: const Icon(Icons.favorite_border_rounded, size: 22),
                onTap: () => context.push(AppRoutes.favorites),
              ),
              PremiumListRow(
                title: 'History',
                subtitle: 'Recent routes and searches',
                leading: const Icon(Icons.history_rounded, size: 22),
                onTap: () => context.push(AppRoutes.history),
              ),
              PremiumListRow(
                title: t('cached_routes'),
                subtitle: t('cached_routes_subtitle'),
                leading: const Icon(Icons.route_rounded, size: 22),
                onTap: () => context.push(AppRoutes.cachedRoutes),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionLabel('Safety & support'),
          PremiumSurface(
            children: [
              PremiumListRow(
                title: 'Emergency',
                subtitle: 'Hotlines and nearby facilities',
                leading: const Icon(Icons.emergency_outlined, size: 22),
                onTap: () => context.push(AppRoutes.emergency),
              ),
              PremiumListRow(
                title: 'Notifications',
                subtitle: unread > 0
                    ? '$unread unread announcement${unread == 1 ? '' : 's'}'
                    : 'Route updates and news',
                leading: const Icon(Icons.notifications_outlined, size: 22),
                onTap: (isGuest && !offline) ? null : () => context.push(AppRoutes.notifications),
              ),
              if (user != null && !isGuest && !offline && !isLocal)
                PremiumListRow(
                  title: 'Report an issue',
                  subtitle: 'Incorrect fare, route, or place',
                  leading: const Icon(Icons.flag_outlined, size: 22),
                  onTap: () => context.push(AppRoutes.reportIssue),
                ),
              if (isAdmin)
                PremiumListRow(
                  title: 'Admin dashboard',
                  subtitle: 'Announcements and analytics',
                  leading: const Icon(Icons.admin_panel_settings_outlined, size: 22),
                  onTap: () => context.push(AppRoutes.admin),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionLabel('Preferences'),
          PremiumSurface(
            children: [
              PremiumListRow(
                title: t('accessibility'),
                subtitle: 'Text size and motion',
                leading: const Icon(Icons.accessibility_new_rounded, size: 22),
                onTap: () => context.push(AppRoutes.accessibility),
              ),
              if (_developerModeEnabled)
                PremiumListRow(
                  title: 'Developer mode',
                  subtitle: 'Reset data and debug tools',
                  leading: const Icon(Icons.developer_mode_outlined, size: 22),
                  onTap: () => context.push(AppRoutes.developerMode),
                ),
            ],
          ),
          if (user != null && !isGuest && !offline && !isLocal) ...[
            const SizedBox(height: 24),
            PremiumSurface(
              children: [
                PremiumListRow(
                  title: t('delete_account'),
                  subtitle: t('delete_account_subtitle'),
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(t('delete_account')),
                        content: const Text(
                          'This permanently deletes your account, favorites, history, and AI chat history.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final success =
                        await ref.read(authNotifierProvider.notifier).deleteAccount();
                    if (!context.mounted) return;
                    if (success) {
                      context.go(AppRoutes.login);
                    } else {
                      final error = ref.read(authNotifierProvider).errorMessage;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error ?? 'Unable to delete account')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          if (!offline || isLocal)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  if (offline && isLocal) {
                    await ref.read(authNotifierProvider.notifier).resetLocalSession();
                    if (context.mounted) context.go(AppRoutes.onboarding);
                    return;
                  }
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                child: Text(offline ? 'Reset local profile' : t('sign_out')),
              ),
            )
          else if (isGuest)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(t('sign_in')),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                child: Text(t('sign_out')),
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _onVersionTap,
              child: Text(
                offline
                    ? 'PINPOINT v${AppConstants.appVersion} · Offline-first'
                    : 'PINPOINT v${AppConstants.appVersion}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

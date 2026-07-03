import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/core/localization/pinpoint_localizations.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
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
      appBar: AppBar(title: Text(t('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      isGuest ? Icons.person_outline : Icons.person,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Guest',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (user != null && !isGuest && !isLocal)
                          Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                        if (isLocal)
                          Text(
                            'Local profile · stored on this device',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (isGuest && !offline)
                          Text(
                            'Sign in to sync favorites and history',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_brightness)),
            ],
            selected: {themeMode},
            onSelectionChanged: (modes) {
              ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _SettingsTile(
            icon: Icons.favorite_outline,
            title: 'Favorites',
            subtitle: isGuest && !offline ? 'Sign in to save favorites' : 'Manage saved places',
            onTap: () => context.push(AppRoutes.favorites),
          ),
          _SettingsTile(
            icon: Icons.history,
            title: 'History',
            subtitle: 'Recent searches and routes',
            onTap: () => context.push(AppRoutes.history),
          ),
          _SettingsTile(
            icon: Icons.emergency_rounded,
            title: 'Emergency',
            subtitle: 'Hotlines and nearby facilities',
            onTap: () => context.push(AppRoutes.emergency),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: unread > 0 ? '$unread unread announcement${unread == 1 ? '' : 's'}' : 'Route updates and announcements',
            onTap: (isGuest && !offline) ? () {} : () => context.push(AppRoutes.notifications),
          ),
          if (user != null && !isGuest && !offline && !isLocal)
            _SettingsTile(
              icon: Icons.flag_outlined,
              title: 'Report an Issue',
              subtitle: 'Incorrect fare, route, or place information',
              onTap: () => context.push(AppRoutes.reportIssue),
            ),
          if (isAdmin)
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Dashboard',
              subtitle: 'Manage announcements, reports, and analytics',
              onTap: () => context.push(AppRoutes.admin),
            ),
          _SettingsTile(
            icon: Icons.route_rounded,
            title: t('cached_routes'),
            subtitle: t('cached_routes_subtitle'),
            onTap: () => context.push(AppRoutes.cachedRoutes),
          ),
          _SettingsTile(
            icon: Icons.accessibility_new_rounded,
            title: t('accessibility'),
            subtitle: 'Large text, contrast, reduced motion',
            onTap: () => context.push(AppRoutes.accessibility),
          ),
          if (_developerModeEnabled)
            _SettingsTile(
              icon: Icons.developer_mode_outlined,
              title: 'Developer Mode',
              subtitle: 'Reset data, reseed assets, simulate first launch',
              onTap: () => context.push(AppRoutes.developerMode),
            ),
          if (user != null && !isGuest && !offline && !isLocal) ...[
            const SizedBox(height: AppSpacing.lg),
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              title: t('delete_account'),
              subtitle: t('delete_account_subtitle'),
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
                final success = await ref.read(authNotifierProvider.notifier).deleteAccount();
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
          if (!offline || isLocal) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
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
          ] else if (isGuest) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text(t('sign_in')),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              },
              child: Text(t('sign_out')),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

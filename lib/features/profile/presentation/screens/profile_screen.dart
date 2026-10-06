import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/core/localization/pinpoint_localizations.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
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
  bool _confirmDelete = false;

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
          Text('Profile', style: Theme.of(context).textTheme.displayLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.signal,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                  border: Border.all(color: AppColors.edgeOf(Theme.of(context).brightness), width: 2),
                ),
                child: Text(
                  (user?.fullName.trim().isNotEmpty == true ? user!.fullName.trim()[0] : 'P').toUpperCase(),
                  style: const TextStyle(color: AppColors.ink, fontSize: 32, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName.trim().isNotEmpty == true
                          ? user!.fullName
                          : (isGuest ? 'Guest traveler' : 'PINPOINT user'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    Text(
                      isGuest && !offline
                          ? 'Sign in to sync favorites and history'
                          : isLocal
                              ? 'Saved on this device'
                              : (user!.email.isNotEmpty ? user.email : 'Butuan City traveler'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inkOf(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            color: AppColors.stageOf(Theme.of(context).brightness),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
          const PremiumSectionLabel('Your places'),
          PremiumSurface(
            children: [
              PremiumListRow(
                title: 'Favorites',
                subtitle: isGuest && !offline ? 'Sign in to sync' : 'Places you saved',
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
                title: 'Saved routes',
                subtitle: 'Works without a connection',
                leading: const Icon(Icons.route_rounded, size: 22),
                onTap: () => context.push(AppRoutes.cachedRoutes),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionLabel('Safety and help'),
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
          if (isAdmin) ...[
            const SizedBox(height: 24),
            const PremiumSectionLabel('Admin'),
            PremiumSurface(
              children: [
                PremiumListRow(
                  title: 'Admin dashboard',
                  subtitle: 'Admin only',
                  leading: const Icon(Icons.admin_panel_settings_outlined, size: 22),
                  onTap: () => context.push(AppRoutes.admin),
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
          const SizedBox(height: 16),
          if (user != null && !isGuest && !offline && !isLocal)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => setState(() => _confirmDelete = !_confirmDelete),
                  child: Text(
                    'Delete account',
                    style: TextStyle(color: AppColors.dangerOf(Theme.of(context).brightness)),
                  ),
                ),
                if (_confirmDelete)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "This permanently removes your account, saved places and routes. You can't undo it.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setState(() => _confirmDelete = false),
                          child: const Text('Keep account', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.dangerOf(Theme.of(context).brightness),
                          ),
                          onPressed: () async {
                            final success = await ref
                                .read(authNotifierProvider.notifier)
                                .deleteAccount();
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
                          child: const Text('Delete account', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/favorites/data/favorites_local_datasource.dart';
import 'package:pinpoint/features/history/data/history_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hidden developer tools for offline-first testing and demos.
class DeveloperModeScreen extends ConsumerStatefulWidget {
  const DeveloperModeScreen({super.key});

  @override
  ConsumerState<DeveloperModeScreen> createState() => _DeveloperModeScreenState();
}

class _DeveloperModeScreenState extends ConsumerState<DeveloperModeScreen> {
  String? _status;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _status = '$label…');
    try {
      await action();
      if (mounted) setState(() => _status = '$label completed.');
    } catch (error) {
      if (mounted) setState(() => _status = '$label failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Mode')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          const Text(
            'Tools for resetting local data, reseeding bundled assets, and simulating first launch.',
          ),
          if (_status != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ActionTile(
            title: 'Reseed bundled assets',
            subtitle: 'Re-import JSON into local Hive cache',
            onTap: () => _run('Reseed', () => ref.read(localSeedServiceProvider).seedAll()),
          ),
          _ActionTile(
            title: 'Reset local database',
            subtitle: 'Clear caches and reseed from assets',
            onTap: () => _run('Reset database', () => ref.read(localSeedServiceProvider).resetAll()),
          ),
          _ActionTile(
            title: 'Clear favorites',
            subtitle: 'Remove all saved favorites',
            onTap: () => _run('Clear favorites', () => FavoritesLocalDataSource().clear()),
          ),
          _ActionTile(
            title: 'Clear history',
            subtitle: 'Remove search and route history',
            onTap: () => _run('Clear history', () => HistoryLocalDataSource().clear()),
          ),
          _ActionTile(
            title: 'Simulate first launch',
            subtitle: 'Clear profile, onboarding, and caches',
            onTap: () => _run('Simulate first launch', () async {
              await ref.read(localProfileServiceProvider).clearProfile();
              await ref.read(authLocalDataSourceProvider).setOnboardingComplete(value: false);
              await ref.read(localSeedServiceProvider).resetAll();
              await ref.read(authNotifierProvider.notifier).resetLocalSession();
              if (mounted) context.go(AppRoutes.onboarding);
            }),
          ),
          _ActionTile(
            title: 'Disable developer mode',
            subtitle: 'Hide developer tools from profile',
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.developerModeKey, false);
              if (mounted) context.pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_arrow_rounded),
        onTap: onTap,
      ),
    );
  }
}

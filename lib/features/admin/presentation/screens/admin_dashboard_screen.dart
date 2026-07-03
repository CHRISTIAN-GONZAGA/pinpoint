import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/admin_notifier.dart';

/// Administrator dashboard for managing PINPOINT content.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminNotifierProvider.notifier).load());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final success = await ref.read(adminNotifierProvider.notifier).publishAnnouncement(
          title: _titleController.text,
          content: _contentController.text,
          category: 'transport',
          priority: 'high',
        );
    if (!mounted) return;
    if (success) {
      _titleController.clear();
      _contentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement published')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final stats = state.dashboard;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatCard(label: 'Users', value: '${stats['total_users'] ?? 0}'),
                    _StatCard(label: 'Routes', value: '${stats['routes'] ?? 0}'),
                    _StatCard(label: 'Attractions', value: '${stats['attractions'] ?? 0}'),
                    _StatCard(label: 'Open Reports', value: '${stats['open_reports'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Publish Announcement', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _contentController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: state.isPublishing ? null : _publish,
                  icon: state.isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Publish & Notify Users'),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Open Reports', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                if (state.reports.isEmpty)
                  const Text('No open reports.')
                else
                  ...state.reports.map((report) {
                    return Card(
                      child: ListTile(
                        title: Text(report['category'] as String? ?? 'Report'),
                        subtitle: Text(report['description'] as String? ?? ''),
                        trailing: TextButton(
                          onPressed: () => ref
                              .read(adminNotifierProvider.notifier)
                              .resolveReport(report['report_id'] as int),
                          child: const Text('Resolve'),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

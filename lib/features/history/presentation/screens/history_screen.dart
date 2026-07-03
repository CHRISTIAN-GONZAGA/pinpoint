import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/history/presentation/viewmodels/history_notifier.dart';

/// Search and navigation history screen.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(historyNotifierProvider.notifier).clearAll(),
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: state.isLoading
          ? const LoadingOverlay(message: 'Loading history...')
          : state.items.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.history_rounded,
                  title: 'No history yet',
                  message: 'Your recent searches and viewed places will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          item.searchType == 'route'
                              ? Icons.route_rounded
                              : Icons.history_rounded,
                        ),
                        title: Text(item.query),
                        subtitle: Text(item.searchType),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              ref.read(historyNotifierProvider.notifier).remove(item),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

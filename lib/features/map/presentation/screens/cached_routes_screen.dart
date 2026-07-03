import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';

/// Shows recently planned routes stored for offline reference.
class CachedRoutesScreen extends ConsumerStatefulWidget {
  const CachedRoutesScreen({super.key});

  @override
  ConsumerState<CachedRoutesScreen> createState() => _CachedRoutesScreenState();
}

class _CachedRoutesScreenState extends ConsumerState<CachedRoutesScreen> {
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final routes = await ref.read(routeCacheServiceProvider).getRecentRoutes();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  Future<void> _clear() async {
    await ref.read(routeCacheServiceProvider).clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
        actions: [
          if (_routes.isNotEmpty)
            TextButton(onPressed: _clear, child: const Text('Clear')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.route_rounded,
                  title: 'No saved routes',
                  message: 'Plan a route on the map to save it for offline viewing.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.route_rounded),
                        title: Text('${route['origin_label']} → ${route['destination_label']}'),
                        subtitle: Text(
                          '${route['duration_label']} • ${route['distance_label']} • ₱${route['estimated_fare']}',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

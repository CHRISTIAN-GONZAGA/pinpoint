import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Expandable search bar with autocomplete suggestions.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.isSearching,
    required this.results,
    required this.onSelect,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool isSearching;
  final List<MapLocation> results;
  final ValueChanged<MapLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search destination in Butuan...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: onClear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
        ),
        if (results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length.clamp(0, 5),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    result.label ?? 'Selected location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () => onSelect(result),
                );
              },
            ),
          ),
      ],
    );
  }
}

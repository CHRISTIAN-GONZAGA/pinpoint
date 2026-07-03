import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Debounced destination search with autocomplete suggestions.
class DestinationSearchField extends StatefulWidget {
  const DestinationSearchField({
    super.key,
    required this.onQueryChanged,
    required this.onSelect,
    required this.results,
    required this.isSearching,
    this.hintText = 'Where do you want to go?',
    this.autofocus = false,
  });

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<MapLocation> onSelect;
  final List<MapLocation> results;
  final bool isSearching;
  final String hintText;
  final bool autofocus;

  @override
  State<DestinationSearchField> createState() => _DestinationSearchFieldState();
}

class _DestinationSearchFieldState extends State<DestinationSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onQueryChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    widget.onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: widget.isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: _clear)
                      : const Icon(Icons.mic_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
        ),
        if (widget.results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.results.length.clamp(0, 6),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = widget.results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    result.label ?? 'Selected location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => widget.onSelect(result),
                );
              },
            ),
          ),
      ],
    );
  }
}

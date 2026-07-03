import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/empty_state_widget.dart';
import 'package:pinpoint/core/widgets/place_card.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_notifier.dart';

/// List of places filtered by category.
class CategoryPlacesScreen extends ConsumerStatefulWidget {
  const CategoryPlacesScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryPlacesScreen> createState() => _CategoryPlacesScreenState();
}

class _CategoryPlacesScreenState extends ConsumerState<CategoryPlacesScreen> {
  List<Place> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cat = PlaceUtils.categories.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => PlaceUtils.categories.first,
    );
    final apiCategory = cat.apiCategory ?? cat.id;
    final places =
        await ref.read(exploreNotifierProvider.notifier).loadCategory(apiCategory);
    if (!mounted) return;
    setState(() {
      _places = places;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cat = PlaceUtils.categories.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => PlaceUtils.categories.first,
    );

    return Scaffold(
      appBar: AppBar(title: Text(cat.label)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.search_off_rounded,
                  title: 'No places found',
                  message: 'No verified places in this category yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    return PlaceCard(
                      place: place,
                      onTap: () => context.push(
                        AppRoutes.placeDetail(place.placeType, place.id),
                      ),
                    );
                  },
                ),
    );
  }
}

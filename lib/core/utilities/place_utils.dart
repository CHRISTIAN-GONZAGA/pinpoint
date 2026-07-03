import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Category icons and labels for places UI.
abstract final class PlaceUtils {
  static const categories = [
    ExploreCategory(id: 'attractions', label: 'Attractions', iconName: 'attractions', apiCategory: 'museum'),
    ExploreCategory(id: 'restaurant', label: 'Restaurants', iconName: 'restaurant', apiCategory: 'restaurant'),
    ExploreCategory(id: 'hotel', label: 'Hotels', iconName: 'hotel', apiCategory: 'hotel'),
    ExploreCategory(id: 'hospital', label: 'Hospitals', iconName: 'hospital', apiCategory: 'hospital'),
    ExploreCategory(id: 'police', label: 'Police', iconName: 'police', apiCategory: 'police'),
    ExploreCategory(id: 'government', label: 'Government', iconName: 'government', apiCategory: 'government'),
    ExploreCategory(id: 'pharmacy', label: 'Pharmacies', iconName: 'pharmacy', apiCategory: 'pharmacy'),
    ExploreCategory(id: 'shopping_center', label: 'Shopping', iconName: 'shopping', apiCategory: 'shopping_center'),
  ];

  static IconData iconForCategory(String? category) {
    return switch (category) {
      'restaurant' => Icons.restaurant_rounded,
      'hotel' => Icons.hotel_rounded,
      'hospital' => Icons.local_hospital_rounded,
      'police' => Icons.local_police_rounded,
      'fire' => Icons.local_fire_department_rounded,
      'pharmacy' => Icons.local_pharmacy_rounded,
      'government' => Icons.account_balance_rounded,
      'shopping_center' => Icons.shopping_bag_rounded,
      'atm' => Icons.atm_rounded,
      'gas_station' => Icons.local_gas_station_rounded,
      'convenience_store' => Icons.store_rounded,
      'museum' || 'park' || 'attraction' => Icons.attractions_rounded,
      'disaster' => Icons.warning_amber_rounded,
      'tourism' => Icons.tour_rounded,
      _ => Icons.place_rounded,
    };
  }

  static Color colorForCategory(String? category) {
    return switch (category) {
      'restaurant' => AppColors.warning,
      'hotel' => const Color(0xFF8B5CF6),
      'hospital' => AppColors.danger,
      'police' => AppColors.primary,
      'fire' => AppColors.danger,
      'pharmacy' => AppColors.danger,
      'museum' || 'park' || 'attraction' => AppColors.accent,
      'government' => Colors.grey,
      'shopping_center' => AppColors.secondary,
      _ => AppColors.primary,
    };
  }

  static String labelForCategory(String? category) {
    if (category == null) return 'Place';
    return category.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/widgets/error_state_widget.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Emergency services quick access screen.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await ref.read(placesRepositoryProvider).getEmergencyContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _call(String hotline) async {
    final digits = hotline.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareLocation() async {
    final location = ref.read(mapNotifierProvider).currentLocation;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location unavailable')),
      );
      return;
    }
    final text =
        'My current location in Butuan: ${location.latitude}, ${location.longitude}';
    await Share.share(text);
  }

  void _viewOnMap(EmergencyContact contact) {
    if (contact.latitude == null || contact.longitude == null) return;
    ref.read(mapNotifierProvider.notifier).selectDestination(
          MapLocation(
            latitude: contact.latitude!,
            longitude: contact.longitude!,
            label: contact.agency,
          ),
        );
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: _isLoading
          ? const LoadingOverlay(message: 'Loading emergency contacts...')
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: AppColors.emergencyGradient,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.emergency_rounded, color: Colors.white, size: 32),
                              SizedBox(width: AppSpacing.md),
                              Text(
                                'Need help now?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _call('911'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.danger,
                                  ),
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('Call 911'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton.filled(
                                onPressed: _shareLocation,
                                style: IconButton.styleFrom(backgroundColor: Colors.white),
                                color: AppColors.danger,
                                icon: const Icon(Icons.share_location_rounded),
                                tooltip: 'Share location',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Emergency Contacts', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    ..._contacts.map((contact) {
                      final color = PlaceUtils.colorForCategory(contact.category);
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(
                              PlaceUtils.iconForCategory(contact.category),
                              color: color,
                            ),
                          ),
                          title: Text(contact.agency),
                          subtitle: Text(
                            '${contact.hotline}${contact.availability != null ? ' · ${contact.availability}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (contact.latitude != null)
                                IconButton(
                                  icon: const Icon(Icons.map_outlined),
                                  onPressed: () => _viewOnMap(contact),
                                ),
                              IconButton(
                                icon: const Icon(Icons.call_rounded, color: AppColors.danger),
                                onPressed: () => _call(contact.hotline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

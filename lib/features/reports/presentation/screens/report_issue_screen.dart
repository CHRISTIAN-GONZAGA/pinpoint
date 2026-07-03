import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Submit a transport or tourism issue report.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _descriptionController = TextEditingController();
  String _category = 'incorrect_fare';
  var _isSubmitting = false;

  static const _categories = [
    ('incorrect_fare', 'Incorrect fare'),
    ('wrong_route', 'Wrong route information'),
    ('missing_stop', 'Missing stop'),
    ('tourist_info', 'Tourist information issue'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;
    setState(() => _isSubmitting = true);
    final location = ref.read(mapNotifierProvider).currentLocation;
    try {
      await ref.read(reportsRepositoryProvider).submit(
            category: _category,
            description: description,
            latitude: location?.latitude,
            longitude: location?.longitude,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you!')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('AppException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Text(
            'Help improve PINPOINT by reporting incorrect fares, routes, or place information.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: _categories
                    .map((item) => DropdownMenuItem(value: item.$1, child: Text(item.$2)))
                    .toList(),
                onChanged: _isSubmitting ? null : (value) => setState(() => _category = value!),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the issue with as much detail as possible.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Accessibility and emergency profile settings.
class AccessibilityScreen extends ConsumerStatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  ConsumerState<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends ConsumerState<AccessibilityScreen> {
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final settings = ref.read(accessibilityNotifierProvider);
      _language = settings.languageCode;
      _emergencyNameController.text = settings.emergencyContactName ?? '';
      _emergencyPhoneController.text = settings.emergencyContactPhone ?? '';
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = ref.read(accessibilityNotifierProvider);
    await ref.read(accessibilityNotifierProvider.notifier).update(
          current.copyWith(
            languageCode: _language,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactPhone: _emergencyPhoneController.text.trim(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accessibility settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          SwitchListTile(
            title: const Text('Large text'),
            subtitle: const Text('Increase text size across the app'),
            value: settings.largeText,
            onChanged: (value) => ref
                .read(accessibilityNotifierProvider.notifier)
                .update(settings.copyWith(largeText: value)),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text('Minimize animations for comfort'),
            value: settings.reduceMotion,
            onChanged: (value) => ref
                .read(accessibilityNotifierProvider.notifier)
                .update(settings.copyWith(reduceMotion: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Preferred language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'tl', child: Text('Tagalog')),
                  DropdownMenuItem(value: 'ceb', child: Text('Cebuano')),
                ],
                onChanged: (value) => setState(() => _language = value ?? 'en'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Emergency contact profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _emergencyNameController,
            decoration: const InputDecoration(
              labelText: 'Contact name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _emergencyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Contact phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
        ],
      ),
    );
  }
}

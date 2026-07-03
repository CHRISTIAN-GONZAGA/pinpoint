import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Text-only ghost button for tertiary actions.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(label),
      ),
    );
  }
}

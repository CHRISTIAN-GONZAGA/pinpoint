import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/widgets/ghost_button.dart';
import 'package:pinpoint/core/widgets/primary_button.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.message,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String message;
  final IconData icon;
  final List<Color> gradient;
}

/// Three-page animated onboarding experience for first-time users.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _nameController = TextEditingController();
  int _currentPage = 0;
  String _languageCode = 'en';

  static const _pages = [
    _OnboardingPage(
      title: 'Discover Butuan',
      message:
          'Discover transportation and attractions in Butuan with confidence.',
      icon: Icons.map_rounded,
      gradient: [AppColors.primary, AppColors.secondary],
    ),
    _OnboardingPage(
      title: 'Navigate Smarter',
      message: 'Find the best transportation route using official local data.',
      icon: Icons.route_rounded,
      gradient: [Color(0xFF1A3A6B), AppColors.accent],
    ),
    _OnboardingPage(
      title: 'Travel with Confidence',
      message:
          'Receive transportation guidance and local travel assistance in multiple languages.',
      icon: Icons.smart_toy_rounded,
      gradient: [AppColors.secondary, AppColors.primary],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (AppConstants.offlineFirstMode) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name to continue.')),
        );
        return;
      }
      final success = await ref.read(authNotifierProvider.notifier).setupLocalProfile(
            name: name,
            languageCode: _languageCode,
          );
      if (!mounted) return;
      if (success) {
        context.go(AppRoutes.home);
      }
      return;
    }

    await ref.read(authNotifierProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final offline = AppConstants.offlineFirstMode;
    final pageCount = offline ? _pages.length + 1 : _pages.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GhostButton(label: 'Skip', onPressed: _finish),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pageCount,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  if (offline && index == _pages.length) {
                    return _ProfileSetupPage(
                      nameController: _nameController,
                      languageCode: _languageCode,
                      onLanguageChanged: (code) => setState(() => _languageCode = code),
                    );
                  }
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: page.gradient),
                            boxShadow: [
                              BoxShadow(
                                color: page.gradient.last.withValues(alpha: 0.3),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(page.icon, size: 88, color: Colors.white),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          page.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.message,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: PrimaryButton(
                label: _currentPage == pageCount - 1 ? 'Get Started' : 'Next',
                onPressed: () {
                  if (_currentPage < pageCount - 1) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    _finish();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSetupPage extends StatelessWidget {
  const _ProfileSetupPage({
    required this.nameController,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  final TextEditingController nameController;
  final String languageCode;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set up your profile',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'PINPOINT works fully offline. Your profile is stored only on this device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: languageCode,
            decoration: const InputDecoration(
              labelText: 'Preferred language',
              prefixIcon: Icon(Icons.translate_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'tl', child: Text('Tagalog')),
              DropdownMenuItem(value: 'ceb', child: Text('Bisaya')),
            ],
            onChanged: (value) {
              if (value != null) onLanguageChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

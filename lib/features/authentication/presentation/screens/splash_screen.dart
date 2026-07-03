import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/widgets/pinpoint_logo.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';

/// Animated splash screen shown on every app launch.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    if (AppConstants.offlineFirstMode) {
      await ref.read(localSeedServiceProvider).seedIfNeeded();
    }

    await Future<void>.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    if (!auth.isInitialized) {
      await ref.read(authNotifierProvider.notifier).initialize();
    }

    if (!mounted) return;
    final updated = ref.read(authNotifierProvider);

    if (updated.hasSession) {
      if (AppConstants.offlineFirstMode) {
        ref.read(notificationsNotifierProvider.notifier).loadAnnouncements();
      }
      context.go(AppRoutes.home);
      return;
    }

    final onboardingComplete =
        await ref.read(authNotifierProvider.notifier).isOnboardingComplete();
    if (!mounted) return;

    if (AppConstants.offlineFirstMode) {
      context.go(AppRoutes.onboarding);
      return;
    }

    if (onboardingComplete) {
      context.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          ),
          ...List.generate(3, (index) {
            return Positioned(
              left: 40.0 + index * 80,
              top: 120.0 + index * 60,
              child: Container(
                width: 120,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.secondary.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate(delay: (300 + index * 200).ms)
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.2, 1), end: const Offset(1, 1)),
            );
          }),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PinpointLogo(size: 110, pulsing: true)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppConstants.appTagline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                )
                    .animate(delay: 800.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  AppConstants.cityName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 1.2,
                      ),
                ).animate(delay: 1200.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

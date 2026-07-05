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
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    if (AppConstants.offlineFirstMode) {
      setState(() => _progress = 0.25);
      await ref.read(localSeedServiceProvider).seedIfNeeded();
    }

    setState(() => _progress = 0.55);
    await Future<void>.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    setState(() => _progress = 0.85);
    final auth = ref.read(authNotifierProvider);
    if (!auth.isInitialized) {
      await ref.read(authNotifierProvider.notifier).initialize();
    }

    if (!mounted) return;
    setState(() => _progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.nightGradient)),
          ...List.generate(4, (index) {
            return Positioned(
              left: -40.0 + index * 90,
              top: 80.0 + index * 70,
              child: _RouteLinePulse(index: index),
            );
          }),
          ...List.generate(3, (index) {
            final size = 180.0 + index * 60;
            return Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.08 - index * 0.02),
                    width: 1.5,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.08, 1.08),
                    duration: (2200 + index * 400).ms,
                    curve: Curves.easeInOut,
                  )
                  .fadeIn(duration: 600.ms),
            );
          }),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PinpointLogo(size: 120, pulsing: true, showTitle: true)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppConstants.appTagline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppConstants.cityName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                ).animate(delay: 700.ms).fadeIn(duration: 450.ms),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: AppColors.secondary,
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Loading your city guide…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                ).animate(delay: 400.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLinePulse extends StatelessWidget {
  const _RouteLinePulse({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(140, 80),
      painter: _RouteArcPainter(
        color: AppColors.secondary.withValues(alpha: 0.35),
      ),
    )
        .animate(delay: (200 + index * 150).ms)
        .fadeIn(duration: 700.ms)
        .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic);
  }
}

class _RouteArcPainter extends CustomPainter {
  _RouteArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.4);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width, size.height * 0.4), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

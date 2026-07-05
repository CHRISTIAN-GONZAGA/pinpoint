import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/services/connectivity_service.dart';
import 'package:pinpoint/core/localization/pinpoint_localizations.dart';
import 'package:pinpoint/core/accessibility/accessibility_notifier.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';

/// Root PINPOINT application widget.
class PinpointApp extends ConsumerStatefulWidget {
  const PinpointApp({super.key});

  @override
  ConsumerState<PinpointApp> createState() => _PinpointAppState();
}

class _PinpointAppState extends ConsumerState<PinpointApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(themeModeProvider.notifier).load();
      await ref.read(accessibilityNotifierProvider.notifier).load();
      await ref.read(authNotifierProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final online = ref.watch(isOnlineProvider);
    final accessibility = ref.watch(accessibilityNotifierProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: PinpointThemes.light,
      darkTheme: PinpointThemes.dark,
      themeMode: themeMode,
      locale: Locale(accessibility.languageCode),
      supportedLocales: PinpointLocalizations.supportedLanguageCodes
          .map((code) => Locale(code))
          .toList(),
      routerConfig: router,
      builder: (context, child) {
        final scaledChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(accessibility.textScaleFactor),
            disableAnimations: accessibility.reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );

        final routePath = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
        final hideStatusBanner = routePath == AppRoutes.splash;

        return Column(
          children: [
            if (!hideStatusBanner)
              _AppStatusBar(
                languageCode: accessibility.languageCode,
                online: online,
              ),
            Expanded(child: scaledChild),
          ],
        );
      },
    );
  }
}

class _AppStatusBar extends StatelessWidget {
  const _AppStatusBar({required this.languageCode, required this.online});

  final String languageCode;
  final AsyncValue<bool> online;

  @override
  Widget build(BuildContext context) {
    final showOfflineFirst = AppConstants.offlineFirstMode;
    final showOffline = online.when(
      data: (connected) => !connected,
      loading: () => false,
      error: (error, stackTrace) => false,
    );

    if (!showOfflineFirst && !showOffline) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 1,
      color: showOffline
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.95)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(
                showOffline ? Icons.wifi_off_rounded : Icons.offline_bolt_rounded,
                size: 18,
                color: showOffline
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  showOffline
                      ? PinpointLocalizations.t('offline_notice', languageCode)
                      : PinpointLocalizations.t('offline_first_notice', languageCode),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: showOffline
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

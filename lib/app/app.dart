import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return Stack(
          children: [
            scaledChild,
            online.when(
              data: (connected) => connected
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: _OfflineNotice(languageCode: accessibility.languageCode),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                PinpointLocalizations.t('offline_notice', languageCode),
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

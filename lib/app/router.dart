import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/login_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/reset_password_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/onboarding_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/register_screen.dart';
import 'package:pinpoint/features/authentication/presentation/screens/splash_screen.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/emergency/presentation/screens/emergency_screen.dart';
import 'package:pinpoint/features/explore/presentation/screens/category_places_screen.dart';
import 'package:pinpoint/features/explore/presentation/screens/place_detail_screen.dart';
import 'package:pinpoint/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:pinpoint/features/history/presentation/screens/history_screen.dart';
import 'package:pinpoint/features/explore/presentation/screens/explore_screen.dart';
import 'package:pinpoint/features/home/presentation/screens/home_screen.dart';
import 'package:pinpoint/features/home/presentation/screens/main_shell_screen.dart';
import 'package:pinpoint/features/map/presentation/screens/map_screen.dart';
import 'package:pinpoint/features/map/presentation/screens/cached_routes_screen.dart';
import 'package:pinpoint/features/profile/presentation/screens/profile_screen.dart';
import 'package:pinpoint/features/profile/presentation/screens/accessibility_screen.dart';
import 'package:pinpoint/features/profile/presentation/screens/developer_mode_screen.dart';
import 'package:pinpoint/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:pinpoint/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:pinpoint/features/reports/presentation/screens/report_issue_screen.dart';

/// Application route paths.
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const map = '/map';
  static const explore = '/explore';
  static const ai = '/ai';
  static const profile = '/profile';
  static const emergency = '/emergency';
  static const favorites = '/favorites';
  static const history = '/history';
  static const notifications = '/notifications';
  static const reportIssue = '/report';
  static const admin = '/admin';
  static const accessibility = '/accessibility';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const cachedRoutes = '/cached-routes';
  static const developerMode = '/developer';

  static String placeDetail(String placeType, int placeId) =>
      '/place/$placeType/$placeId';

  static String category(String categoryId) => '/category/$categoryId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isInitialized = authState.isInitialized;
      final hasSession = authState.hasSession;
      final isAuthRoute = path == AppRoutes.login ||
          path == AppRoutes.register ||
          path == AppRoutes.onboarding ||
          path == AppRoutes.splash;

      if (!isInitialized && path != AppRoutes.splash) {
        return AppRoutes.splash;
      }

      if (isInitialized && hasSession && isAuthRoute && path != AppRoutes.splash) {
        return AppRoutes.home;
      }

      if (AppConstants.offlineFirstMode &&
          isInitialized &&
          !hasSession &&
          path != AppRoutes.onboarding &&
          path != AppRoutes.splash) {
        return AppRoutes.onboarding;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => _slidePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => _slidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => _slidePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        pageBuilder: (context, state) {
          final token = state.extra as String?;
          return _slidePage(state, ResetPasswordScreen(initialToken: token));
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => _slidePage(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.emergency,
        name: 'emergency',
        pageBuilder: (context, state) => _slidePage(state, const EmergencyScreen()),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        name: 'favorites',
        pageBuilder: (context, state) => _slidePage(state, const FavoritesScreen()),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        pageBuilder: (context, state) => _slidePage(state, const HistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        pageBuilder: (context, state) => _slidePage(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: AppRoutes.reportIssue,
        name: 'reportIssue',
        pageBuilder: (context, state) => _slidePage(state, const ReportIssueScreen()),
      ),
      GoRoute(
        path: AppRoutes.cachedRoutes,
        name: 'cachedRoutes',
        pageBuilder: (context, state) => _slidePage(state, const CachedRoutesScreen()),
      ),
      GoRoute(
        path: AppRoutes.developerMode,
        name: 'developerMode',
        pageBuilder: (context, state) => _slidePage(state, const DeveloperModeScreen()),
      ),
      GoRoute(
        path: AppRoutes.accessibility,
        name: 'accessibility',
        pageBuilder: (context, state) => _slidePage(state, const AccessibilityScreen()),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        pageBuilder: (context, state) => _slidePage(state, const AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/place/:placeType/:placeId',
        name: 'placeDetail',
        pageBuilder: (context, state) {
          final placeType = state.pathParameters['placeType']!;
          final placeId = int.parse(state.pathParameters['placeId']!);
          return _slidePage(
            state,
            PlaceDetailScreen(placeType: placeType, placeId: placeId),
          );
        },
      ),
      GoRoute(
        path: '/category/:categoryId',
        name: 'category',
        pageBuilder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          return _slidePage(state, CategoryPlacesScreen(categoryId: categoryId));
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                name: 'map',
                pageBuilder: (context, state) => _fadePage(state, const MapScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                name: 'explore',
                pageBuilder: (context, state) => _fadePage(state, const ExploreScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ai,
                name: 'ai',
                pageBuilder: (context, state) => _fadePage(state, const AiChatScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                pageBuilder: (context, state) => _fadePage(state, const ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 380),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(curved);
      return SlideTransition(
        position: offset,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 420),
  );
}

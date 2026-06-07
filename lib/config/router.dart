import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/screens/auth/login_screen.dart';
import 'package:split_ex/screens/auth/register_screen.dart';
import 'package:split_ex/screens/home/home_screen.dart';
import 'package:split_ex/screens/profile/profile_setup_screen.dart';
import 'package:split_ex/screens/room/create_room_screen.dart';
import 'package:split_ex/screens/room/join_room_screen.dart';
import 'package:split_ex/screens/room/room_detail_screen.dart';
import 'package:split_ex/screens/room/room_settings_screen.dart';
import 'package:split_ex/screens/dashboard/dashboard_screen.dart';
import 'package:split_ex/screens/analytics/analytics_screen.dart';
import 'package:split_ex/screens/reminders/notifications_screen.dart';
import 'package:split_ex/screens/activity/activity_screen.dart';
import 'package:split_ex/screens/admin/storage_management_screen.dart';
import 'package:split_ex/screens/settings/settings_screen.dart';
import 'package:split_ex/screens/settings/edit_profile_screen.dart';
import 'package:split_ex/screens/settings/change_password_screen.dart';
import 'package:split_ex/screens/settings/notification_preferences_screen.dart';
import 'package:split_ex/screens/splash/splash_screen.dart';

/// A notifier that notifies GoRouter when auth state changes without rebuilding the router itself.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(profileExistsProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  // Use read here to prevent the GoRouter instance from being recreated
  // which causes it to reset to the initialLocation ('/splash').
  final notifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final profileExists = ref.read(profileExistsProvider);

      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final matchedLocation = state.matchedLocation;
      
      final isSplash = matchedLocation == '/splash';
      final isAuthRoute = matchedLocation == '/login' || matchedLocation == '/register';
      final isProfileSetup = matchedLocation == '/profile-setup';

      if (!isLoggedIn) {
        return (isAuthRoute || isSplash) ? null : '/login';
      }

      // If logged in but profile existence is still being determined
      if (profileExists.isLoading) return null;
      
      final hasProfile = profileExists.valueOrNull ?? false;

      // Handle transitions from Splash or Auth screens
      if (isSplash || isAuthRoute) {
        return hasProfile ? '/' : '/profile-setup';
      }

      // Ensure user with no profile is sent to setup
      if (!hasProfile && !isProfileSetup) {
        return '/profile-setup';
      }
      
      // Ensure user with profile doesn't stay on setup
      if (hasProfile && isProfileSetup) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/join-room',
        builder: (context, state) => const JoinRoomScreen(),
      ),
      GoRoute(
        path: '/room/:roomId',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final selectedMonthInHome = state.extra as DateTime? ?? DateTime.now();
          var initialTabIndex = 0;
          if (tabParam != null) {
            switch (tabParam) {
              case 'bills':
              case '1':
                initialTabIndex = 1;
                break;
              case 'settlements':
              case '2':
                initialTabIndex = 2;
                break;
            }
          }
          return RoomDetailScreen(
            roomId: state.pathParameters['roomId']!,
            initialTabIndex: initialTabIndex,
            selectedMonthInHome: selectedMonthInHome
          );
        },
      ),
      GoRoute(
        path: '/room/:roomId/activity',
        builder: (context, state) => ActivityScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/room/:roomId/storage',
        builder: (context, state) => StorageManagementScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/room/:roomId/analytics',
        builder: (context, state) => AnalyticsScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/room/:roomId/settings',
        builder: (context, state) => RoomSettingsScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
    ],
  );
});

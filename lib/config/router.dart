import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/screens/auth/login_screen.dart';
import 'package:split_ex/screens/auth/register_screen.dart';
import 'package:split_ex/screens/bills/add_bill_screen.dart';
import 'package:split_ex/screens/expense/add_expense_screen.dart';
import 'package:split_ex/screens/expense/edit_expense_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileExists = ref.watch(profileExistsProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isProfileSetup = state.matchedLocation == '/profile-setup';

      // Don't redirect if we are on splash, let it handle the first navigation
      if (isSplash) return null;

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        final hasProfile = profileExists.valueOrNull ?? false;
        if (!hasProfile) return '/profile-setup';
        return '/';
      }
      if (isLoggedIn && !isProfileSetup && !isAuthRoute) {
        final hasProfile = profileExists.valueOrNull ?? false;
        if (!hasProfile) return '/profile-setup';
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
          );
        },
      ),
      GoRoute(
        path: '/room/:roomId/dashboard',
        builder: (context, state) => DashboardScreen(
          roomId: state.pathParameters['roomId']!,
        ),
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
        path: '/room/:roomId/add-expense',
        builder: (context, state) => AddExpenseScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/room/:roomId/add-bill',
        builder: (context, state) => AddBillScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/room/:roomId/edit-expense',
        builder: (context, state) => EditExpenseScreen(
          roomId: state.pathParameters['roomId']!,
          expense: state.extra as ExpenseModel,
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

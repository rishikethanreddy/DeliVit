import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
// import '../../features/auth/screens/verification_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/home/screens/main_screen.dart';
import '../../features/requests/screens/create_request_screen.dart';
import '../../features/requests/screens/pickup_details_screen.dart';
import '../../features/requests/screens/active_pickup_screen.dart';
import '../../features/profile/screens/pickup_history_screen.dart';
import '../../features/profile/screens/privacy_policy_screen.dart';
import '../../features/profile/screens/terms_of_service_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
// import '../../features/auth/screens/signup_screen.dart';
// import '../../features/home/screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/profile_setup',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ProfileSetupScreen(initialData: extra);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/create_request',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CreateRequestScreen(initialRequest: extra);
      },
    ),
    GoRoute(
      path: '/request_details',
      builder: (context, state) {
        final request = state.extra as Map<String, dynamic>;
        return PickupDetailsScreen(request: request);
      },
    ),
    GoRoute(
      path: '/active_pickup',
      builder: (context, state) {
        final request = state.extra as Map<String, dynamic>;
        return ActivePickupScreen(request: request);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return ChatScreen(
          requestId: args['requestId'],
          otherName: args['otherName'],
          otherAvatar: args['otherAvatar'],
          otherUserId: args['otherUserId'],
        );
      },
    ),
    GoRoute(
      path: '/pickup_history',
      builder: (context, state) => const PickupHistoryScreen(),
    ),
    GoRoute(
      path: '/privacy_policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms_of_service',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
  ],
);

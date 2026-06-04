import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/screens/dob_screen.dart';
import '../features/onboarding/presentation/screens/name_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/share_playing_screen.dart';
import '../features/home/presentation/screens/share_preview_screen.dart';
import '../features/inbox/presentation/screens/inbox_screen.dart';
import '../features/matches/presentation/screens/matches_screen.dart';
import '../features/play/presentation/screens/play_screen.dart';
import '../features/onboarding/presentation/screens/profile_upload_screen.dart';
import '../features/onboarding/presentation/screens/pro_screen.dart';
import '../features/onboarding/presentation/screens/social_media_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../providers/auth_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final authStatus = ref.watch(authStatusProvider);

  return GoRouter(
    initialLocation: '/splash',
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding/dob', builder: (_, _) => const DobScreen()),
      GoRoute(path: '/onboarding/name', builder: (_, _) => const NameScreen()),
      GoRoute(
        path: '/onboarding/profile_upload',
        builder: (_, _) => const ProfileUploadScreen(),
      ),
      GoRoute(
        path: '/onboarding/social_media',
        builder: (_, _) => const SocialMediaScreen(),
      ),
      GoRoute(path: '/onboarding/pro', builder: (_, _) => const ProScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
      GoRoute(path: '/inbox', builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/play', builder: (_, _) => const PlayScreen()),
      GoRoute(path: '/share', builder: (_, _) => const SharePreviewScreen()),
      GoRoute(
        path: '/share/playing',
        builder: (context, state) {
          final autoShare = state.uri.queryParameters['autoShare'] == 'true';
          final platform = state.uri.queryParameters['platform'];
          return SharePlayingScreen(autoShare: autoShare, platform: platform);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This link could not be opened.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                state.error?.toString() ?? 'The requested page was not found.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (_, state) {
      final isLoading = authStatus == AuthStatus.loading;
      final path = state.matchedLocation;
      final isOnboardingRoute = path.startsWith('/onboarding');
      final isAuthenticated = authStatus == AuthStatus.authenticated;

      debugPrint(
        '[Router] redirect check: path=$path, isLoading=$isLoading, '
        'hasSession=${authState.value != null}, '
        'authStatus=$authStatus',
      );

      // While bootstrapping auth/onboarding state, never leave splash.
      if (isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      if (path == '/splash') {
        return isAuthenticated ? '/home' : '/onboarding/dob';
      }

      if (!isLoading && isAuthenticated && isOnboardingRoute) {
        return '/home';
      }

      if (!isLoading && !isAuthenticated && !isOnboardingRoute) {
        return '/onboarding/dob';
      }

      return null;
    },
  );
});

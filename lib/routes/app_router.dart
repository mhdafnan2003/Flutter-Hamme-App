import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/screens/deeplink_screen.dart';
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
import '../providers/onboarding_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final authStatus = ref.watch(authStatusProvider);
  final onboardingCompletionState = ref.watch(onboardingCompletionProvider);

  return GoRouter(
    initialLocation: '/splash',
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/onboarding/deeplink',
        builder: (_, _) => const DeepLinkScreen(),
      ),
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
      GoRoute(path: '/pro', builder: (_, _) => const ProScreen()),
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
    redirect: (_, state) {
      final isLoading = authStatus == AuthStatus.loading || onboardingCompletionState.isLoading;
      final path = state.matchedLocation;
      final isOnboardingComplete = onboardingCompletionState.value ?? false;
      final isOnboardingRoute = path.startsWith('/onboarding');

      debugPrint(
        '[Router] redirect check: path=$path, isLoading=$isLoading, '
        'onboardingComplete=$isOnboardingComplete, hasSession=${authState.value != null}, '
        'authStatus=$authStatus',
      );

      // While bootstrapping auth/onboarding state, never leave splash.
      if (isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      if (path == '/splash') {
        if (authStatus == AuthStatus.authenticated && isOnboardingComplete) {
          return '/home';
        }
        return '/onboarding/deeplink';
      }

      if (!isLoading && isOnboardingComplete && isOnboardingRoute) {
        return '/home';
      }

      return null;
    },
  );
});

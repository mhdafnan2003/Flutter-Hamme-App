import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/screens/dob_screen.dart';
import '../features/onboarding/presentation/screens/name_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
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
  final onboardingCompletionState = ref.watch(onboardingCompletionProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
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
    ],
    redirect: (_, state) {
      final isLoading =
          authState.isLoading || onboardingCompletionState.isLoading;
      final path = state.matchedLocation;
      final isOnboardingComplete = onboardingCompletionState.value ?? false;
      final isOnboardingRoute = path.startsWith('/onboarding');

      if (isLoading && path != '/splash') {
        return '/splash';
      }

      if (!isLoading && path == '/splash') {
        return isOnboardingComplete ? '/home' : '/onboarding/dob';
      }

      if (!isLoading && isOnboardingComplete && isOnboardingRoute) {
        return '/home';
      }

      return null;
    },
  );
});

import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/routes/app_router.dart';

void main() {
  group('authentication redirects', () {
    test('completed authenticated users cannot remain in onboarding', () {
      for (final path in [
        '/onboarding/dob',
        '/onboarding/name',
        '/onboarding/profile_upload',
        '/onboarding/social_media',
        '/onboarding/pro',
      ]) {
        expect(
          resolveAuthRedirect(
            authStatus: AuthStatus.authenticated,
            onboardingComplete: true,
            path: path,
          ),
          '/home',
          reason: 'Expected $path to redirect to Home',
        );
      }
    });

    test(
      'unfinished first-time onboarding can continue after registration',
      () {
        expect(
          resolveAuthRedirect(
            authStatus: AuthStatus.authenticated,
            onboardingComplete: false,
            path: '/onboarding/pro',
          ),
          isNull,
        );
      },
    );

    test('authenticated users never remain on the age screen', () {
      expect(
        resolveAuthRedirect(
          authStatus: AuthStatus.authenticated,
          onboardingComplete: false,
          path: '/onboarding/dob',
        ),
        '/home',
      );
    });

    test('authenticated splash routes to Home', () {
      expect(
        resolveAuthRedirect(
          authStatus: AuthStatus.authenticated,
          onboardingComplete: true,
          path: '/splash',
        ),
        '/home',
      );
    });

    test('unauthenticated protected routes go to age onboarding', () {
      expect(
        resolveAuthRedirect(
          authStatus: AuthStatus.unauthenticated,
          onboardingComplete: false,
          path: '/home',
        ),
        '/onboarding/dob',
      );
    });
  });
}

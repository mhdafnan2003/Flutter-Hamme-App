import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/routes/app_router.dart';
import 'package:hamme_app/routes/route_paths.dart';

String? redirect({
  required AuthStatus authStatus,
  required String path,
  bool onboardingComplete = true,
  bool termsAccepted = true,
  bool accountSuspended = false,
}) {
  return resolveAuthRedirect(
    authStatus: authStatus,
    onboardingComplete: onboardingComplete,
    path: path,
    termsAccepted: termsAccepted,
    accountSuspended: accountSuspended,
  );
}

void main() {
  group('authentication redirects', () {
    test('completed authenticated users cannot remain in onboarding', () {
      for (final path in [
        '/onboarding/dob',
        RoutePaths.onboardingCommunityRules,
        '/onboarding/name',
        '/onboarding/profile_upload',
        '/onboarding/social_media',
        '/onboarding/pro',
      ]) {
        expect(
          redirect(authStatus: AuthStatus.authenticated, path: path),
          '/home',
          reason: 'Expected $path to redirect to Home',
        );
      }
    });

    test(
      'unfinished first-time onboarding can continue after registration',
      () {
        expect(
          redirect(
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
        redirect(
          authStatus: AuthStatus.authenticated,
          onboardingComplete: false,
          path: '/onboarding/dob',
        ),
        '/home',
      );
    });

    test('authenticated splash routes to Home', () {
      expect(
        redirect(authStatus: AuthStatus.authenticated, path: '/splash'),
        '/home',
      );
    });

    test('unauthenticated protected routes go to age onboarding', () {
      expect(
        redirect(
          authStatus: AuthStatus.unauthenticated,
          onboardingComplete: false,
          path: '/home',
        ),
        '/onboarding/dob',
      );
    });

    test('signed-out users can open the sign-up community rules step', () {
      expect(
        redirect(
          authStatus: AuthStatus.unauthenticated,
          onboardingComplete: false,
          path: RoutePaths.onboardingCommunityRules,
        ),
        isNull,
      );
    });
  });

  group('terms gate', () {
    test('users who have not agreed are held on the terms gate', () {
      for (final path in [
        '/home',
        '/play',
        '/inbox',
        '/matches',
        '/profile',
        '/settings',
        '/pro',
        '/share',
        '/splash',
        '/onboarding/dob',
      ]) {
        expect(
          redirect(
            authStatus: AuthStatus.authenticated,
            termsAccepted: false,
            path: path,
          ),
          RoutePaths.termsGate,
          reason: 'Expected $path to redirect to the terms gate',
        );
      }
    });

    test('the terms gate itself is allowed until the user agrees', () {
      expect(
        redirect(
          authStatus: AuthStatus.authenticated,
          termsAccepted: false,
          path: RoutePaths.termsGate,
        ),
        isNull,
      );
    });

    test('the gate never interrupts the sign-up hand-off', () {
      for (final path in ['/onboarding/social_media', '/onboarding/pro']) {
        expect(
          redirect(
            authStatus: AuthStatus.authenticated,
            onboardingComplete: false,
            termsAccepted: false,
            path: path,
          ),
          isNull,
          reason: 'Expected $path to stay reachable during account creation',
        );
      }
    });

    test('agreeing leaves the gate for Home', () {
      expect(
        redirect(
          authStatus: AuthStatus.authenticated,
          path: RoutePaths.termsGate,
        ),
        '/home',
      );
    });

    test('signing out from the gate returns to onboarding', () {
      expect(
        redirect(
          authStatus: AuthStatus.unauthenticated,
          onboardingComplete: false,
          path: RoutePaths.termsGate,
        ),
        '/onboarding/dob',
      );
    });

    test('community guidelines stay readable from anywhere', () {
      for (final status in AuthStatus.values) {
        expect(
          redirect(
            authStatus: status,
            termsAccepted: false,
            path: RoutePaths.communityGuidelines,
          ),
          isNull,
          reason: 'Expected guidelines to be readable while $status',
        );
      }
    });
  });

  group('account suspension', () {
    test('a suspended account only sees the suspension notice', () {
      for (final status in AuthStatus.values) {
        for (final path in [
          '/splash',
          '/home',
          '/onboarding/dob',
          RoutePaths.termsGate,
          RoutePaths.communityGuidelines,
        ]) {
          expect(
            redirect(authStatus: status, accountSuspended: true, path: path),
            RoutePaths.accountSuspended,
          );
        }
        expect(
          redirect(
            authStatus: status,
            accountSuspended: true,
            path: RoutePaths.accountSuspended,
          ),
          isNull,
        );
      }
    });

    test('acknowledging the notice returns to onboarding', () {
      expect(
        redirect(
          authStatus: AuthStatus.unauthenticated,
          onboardingComplete: false,
          path: RoutePaths.accountSuspended,
        ),
        '/onboarding/dob',
      );
    });
  });
}

/// Paths of the community-rules and account-safety routes, shared by the
/// router's redirect logic and the screens that link to them.
abstract final class RoutePaths {
  /// Sign-up step where new users agree to the community rules before their
  /// account is created.
  static const String onboardingCommunityRules = '/onboarding/community_rules';

  /// Blocking gate for signed-in users who haven't agreed to the current
  /// terms version.
  static const String termsGate = '/terms';

  /// Shown after the backend reports the account as banned.
  static const String accountSuspended = '/account-suspended';

  /// In-app Community Guidelines. Readable at any time, signed in or not.
  static const String communityGuidelines = '/settings/community-guidelines';

  /// People and anonymous voters the user blocked, with unblock.
  static const String blockedUsers = '/settings/blocked-users';
}

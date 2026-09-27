/// Community-rules wording shared by the sign-up agreement, the terms gate
/// for existing users and the in-app Community Guidelines.
///
/// [zeroToleranceStatement] is the canonical text also used by the web Terms
/// of Use — keep it verbatim.
abstract final class CommunityRules {
  static const String zeroToleranceStatement =
      'Hamme has zero tolerance for objectionable content or abusive users. '
      'You may not use Hamme to bully, harass, threaten, impersonate, or '
      'sexualize anyone, or to share hateful, violent, sexually explicit, or '
      'otherwise objectionable content — including in your name, username, '
      'profile photo, or linked social handles. You can report or block any '
      'user or anonymous vote from within the app. We review every report '
      'within 24 hours; content that breaks these rules is removed and the '
      'user responsible is banned from Hamme.';

  /// Short version of the rules shown next to the agreement checkbox.
  static const List<String> keyRules = [
    'No bullying, harassment, threats, or hate',
    'No nudity or sexual content — never involving minors',
    'No fake accounts or pretending to be someone else',
    "No spam, scams, or sharing someone's private info",
    'Report or block anyone who breaks these rules — we review every report '
        'within 24 hours',
  ];

  /// Everything that is not allowed, as listed in the Community Guidelines.
  static const List<String> prohibitedContent = [
    'Bullying or harassment',
    'Threats or violence',
    'Hate speech or hateful symbols',
    'Nudity or sexual content — especially anything involving minors',
    'Impersonation or fake accounts',
    'Promoting self-harm or suicide',
    'Spam or scams',
    "Sharing someone else's private information",
  ];

  static const String agreementLabel =
      'I agree to the Terms of Use and Community Guidelines';

  static const String reviewPromise = 'We review every report within 24 hours.';

  static const String emergencyNotice =
      'If someone is in immediate danger, contact your local emergency '
      'services.';

  static const String accountSuspendedMessage =
      'Your account has been suspended for violating the Hamme Terms of Use. '
      'If you think this is a mistake, contact support@hamme.app.';
}

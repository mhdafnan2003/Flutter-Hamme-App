import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';

/// A terms acceptance remembered on this device for one user.
class LocalTermsAcceptance {
  const LocalTermsAcceptance({
    required this.version,
    required this.acceptedAt,
    required this.pendingSync,
    this.lastSyncAttemptAt,
  });

  /// Minimum time between attempts to tell the server about an acceptance.
  static const Duration syncRetryInterval = Duration(hours: 24);

  final int version;
  final DateTime acceptedAt;

  /// True while the server has not confirmed this acceptance yet.
  final bool pendingSync;

  /// When the server was last asked to record it (and didn't).
  final DateTime? lastSyncAttemptAt;

  /// Whether a sync should be attempted now: at most once per
  /// [syncRetryInterval], and never again once the server has confirmed it.
  bool isSyncDue(DateTime now) {
    if (!pendingSync) return false;
    final lastAttempt = lastSyncAttemptAt;
    return lastAttempt == null ||
        now.difference(lastAttempt) >= syncRetryInterval;
  }
}

/// Remembers, per user id, that a user agreed to the Terms of Use / Community
/// Guidelines on this device while the server could not record it.
///
/// The app may ship before the backend can record acceptance
/// (`POST /profiles/me/terms`, `acceptedTermsVersion` on sign-up). Keeping it
/// here means the user is never asked twice; the auth layer retries telling
/// the server at most once a day until it succeeds.
class TermsAcceptanceStore {
  static const _versionKeyPrefix = 'terms_accepted_version_';
  static const _acceptedAtKeyPrefix = 'terms_accepted_at_';
  static const _pendingSyncKeyPrefix = 'terms_pending_sync_';
  static const _syncAttemptKeyPrefix = 'terms_sync_attempted_at_';

  Future<LocalTermsAcceptance?> read(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final version = preferences.getInt('$_versionKeyPrefix$userId');
    if (version == null) return null;
    DateTime? readDate(String keyPrefix) =>
        DateTime.tryParse(preferences.getString('$keyPrefix$userId') ?? '');
    return LocalTermsAcceptance(
      version: version,
      acceptedAt:
          readDate(_acceptedAtKeyPrefix) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pendingSync:
          preferences.getBool('$_pendingSyncKeyPrefix$userId') ?? false,
      lastSyncAttemptAt: readDate(_syncAttemptKeyPrefix),
    );
  }

  /// Saves an acceptance the server has not recorded yet. [syncAttemptedAt]
  /// is when the server was asked (and didn't record it), if it was.
  Future<void> savePending(
    String userId, {
    required int version,
    required DateTime acceptedAt,
    DateTime? syncAttemptedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('$_versionKeyPrefix$userId', version);
    await preferences.setString(
      '$_acceptedAtKeyPrefix$userId',
      acceptedAt.toUtc().toIso8601String(),
    );
    await preferences.setBool('$_pendingSyncKeyPrefix$userId', true);
    if (syncAttemptedAt != null) {
      await recordSyncAttempt(userId, syncAttemptedAt);
    }
  }

  Future<void> recordSyncAttempt(String userId, DateTime at) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_syncAttemptKeyPrefix$userId',
      at.toUtc().toIso8601String(),
    );
  }

  /// The server has recorded the acceptance: stop retrying.
  Future<void> markSynced(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_pendingSyncKeyPrefix$userId', false);
    await preferences.remove('$_syncAttemptKeyPrefix$userId');
  }
}

/// Returns [user] with a locally remembered acceptance applied when the server
/// copy does not (yet) record it. Server data wins whenever it is newer.
AppUser applyLocalTermsAcceptance(AppUser user, LocalTermsAcceptance? local) {
  if (local == null) return user;
  final serverVersion = user.termsVersion ?? 0;
  if (serverVersion >= local.version) return user;
  return user.copyWith(
    termsVersion: local.version,
    termsAcceptedAt: local.acceptedAt,
  );
}

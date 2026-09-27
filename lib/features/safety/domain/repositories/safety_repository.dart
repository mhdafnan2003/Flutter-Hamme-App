import '../models/blocked_users.dart';
import '../models/report_reason.dart';
import '../models/report_result.dart';

/// Report, hide and block — the user-facing safety endpoints.
abstract interface class SafetyRepository {
  /// Reports a vote the user received. The server hides it from them right
  /// away and, when [block] is true, blocks whoever sent it (named user or
  /// anonymous voter). Works for anonymous votes; the response never reveals
  /// who voted.
  Future<ReportResult> reportInteraction(
    String interactionId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  });

  /// Removes a received vote from the user's feeds without reporting it.
  Future<void> hideInteraction(String interactionId);

  /// Blocks whoever sent a vote the user received, without reporting it, and
  /// hides the vote. Works for anonymous voters without revealing them.
  /// Returns false when there was nobody the server could block.
  Future<bool> blockInteractionSender(String interactionId);

  /// Reports a person's profile (name, photo, social handles).
  Future<ReportResult> reportUser(
    String userId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  });

  Future<void> blockUser(String userId);

  Future<BlockedUsersResult> getBlockedUsers();

  Future<void> unblockUser(String userId);

  /// Unblocks every anonymous voter; returns how many were unblocked.
  Future<int> clearAnonymousBlocks();
}

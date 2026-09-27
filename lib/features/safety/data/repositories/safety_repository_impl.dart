import '../../domain/models/blocked_users.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/report_result.dart';
import '../../domain/repositories/safety_repository.dart';
import '../datasources/safety_remote_data_source.dart';

class SafetyRepositoryImpl implements SafetyRepository {
  SafetyRepositoryImpl(this._remoteDataSource);

  final SafetyRemoteDataSource _remoteDataSource;

  @override
  Future<ReportResult> reportInteraction(
    String interactionId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) {
    return _remoteDataSource.reportInteraction(
      interactionId,
      reason: reason,
      details: details,
      block: block,
    );
  }

  @override
  Future<void> hideInteraction(String interactionId) =>
      _remoteDataSource.hideInteraction(interactionId);

  @override
  Future<bool> blockInteractionSender(String interactionId) =>
      _remoteDataSource.blockInteractionSender(interactionId);

  @override
  Future<ReportResult> reportUser(
    String userId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) {
    return _remoteDataSource.reportUser(
      userId,
      reason: reason,
      details: details,
      block: block,
    );
  }

  @override
  Future<void> blockUser(String userId) => _remoteDataSource.blockUser(userId);

  @override
  Future<BlockedUsersResult> getBlockedUsers() =>
      _remoteDataSource.getBlockedUsers();

  @override
  Future<void> unblockUser(String userId) =>
      _remoteDataSource.unblockUser(userId);

  @override
  Future<int> clearAnonymousBlocks() =>
      _remoteDataSource.clearAnonymousBlocks();
}

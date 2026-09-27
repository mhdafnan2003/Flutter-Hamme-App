import '../../../../core/services/api_service.dart';
import '../../domain/models/blocked_users.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/report_result.dart';

class SafetyRemoteDataSource {
  SafetyRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<ReportResult> reportInteraction(
    String interactionId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) async {
    final response = await _apiService.post(
      '/interactions/${_segment(interactionId)}/report',
      authenticated: true,
      body: _reportBody(reason: reason, details: details, block: block),
    );
    return ReportResult.fromJson(_asMap(response));
  }

  Future<void> hideInteraction(String interactionId) async {
    await _apiService.post(
      '/interactions/${_segment(interactionId)}/hide',
      authenticated: true,
    );
  }

  Future<bool> blockInteractionSender(String interactionId) async {
    final response = await _apiService.post(
      '/interactions/${_segment(interactionId)}/block',
      authenticated: true,
    );
    return _asMap(response)['blocked'] == true;
  }

  Future<ReportResult> reportUser(
    String userId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) async {
    final response = await _apiService.post(
      '/profiles/${_segment(userId)}/report',
      authenticated: true,
      body: _reportBody(reason: reason, details: details, block: block),
    );
    return ReportResult.fromJson(_asMap(response));
  }

  Future<void> blockUser(String userId) async {
    await _apiService.post(
      '/profiles/${_segment(userId)}/block',
      authenticated: true,
    );
  }

  Future<BlockedUsersResult> getBlockedUsers() async {
    final response = await _apiService.get(
      '/profiles/me/blocked',
      authenticated: true,
    );
    return BlockedUsersResult.fromJson(_asMap(response));
  }

  Future<void> unblockUser(String userId) async {
    await _apiService.delete(
      '/profiles/me/blocked/${_segment(userId)}',
      authenticated: true,
    );
  }

  Future<int> clearAnonymousBlocks() async {
    final response = await _apiService.delete(
      '/profiles/me/blocked-anonymous',
      authenticated: true,
    );
    return (_asMap(response)['cleared'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic> _reportBody({
    required ReportReason? reason,
    required String? details,
    required bool block,
  }) {
    final normalizedDetails = normalizeReportDetails(details);
    return {
      if (reason != null) 'reason': reason.apiValue,
      if (normalizedDetails != null) 'details': normalizedDetails,
      'block': block,
    };
  }

  static String _segment(String id) => Uri.encodeComponent(id);

  static Map<String, dynamic> _asMap(Object? response) =>
      response is Map<String, dynamic> ? response : const <String, dynamic>{};
}

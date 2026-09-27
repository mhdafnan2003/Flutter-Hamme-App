/// Server response to reporting a vote (`POST /interactions/:id/report`) or a
/// profile (`POST /profiles/:userId/report`).
class ReportResult {
  const ReportResult({
    required this.reportId,
    required this.blocked,
    this.hidden = false,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    return ReportResult(
      reportId: json['reportId']?.toString() ?? '',
      hidden: json['hidden'] == true,
      blocked: json['blocked'] == true,
    );
  }

  final String reportId;

  /// Whether the reported vote was removed from the reporter's feed. Always
  /// true for vote reports; profile reports don't hide anything by themselves.
  final bool hidden;

  /// Whether the sender (named user or anonymous voter) is now blocked.
  final bool blocked;
}

/// Thrown when the vote or person being hidden, reported or blocked no longer
/// exists for the user (HTTP 404) — usually because it was already removed.
class SafetyTargetGoneException implements Exception {
  const SafetyTargetGoneException();

  @override
  String toString() => 'This is no longer available.';
}

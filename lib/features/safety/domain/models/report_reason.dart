/// Why the user is reporting a vote or a profile.
///
/// [apiValue] and [label] mirror the shared UGC-safety contract. The backend
/// stores a missing or unknown reason as [other].
enum ReportReason {
  harassment('harassment', 'Bullying or harassment'),
  sexual('sexual', 'Nudity or sexual content'),
  hate('hate', 'Hate speech or symbols'),
  violence('violence', 'Violence or threats'),
  selfHarm('self_harm', 'Self-harm or suicide'),
  impersonation('impersonation', 'Fake account or impersonation'),
  underage('underage', 'User may be under 13'),
  spam('spam', 'Spam or scam'),
  other('other', 'Something else');

  const ReportReason(this.apiValue, this.label);

  /// Value sent to and received from the API.
  final String apiValue;

  /// Text shown to the user.
  final String label;

  static ReportReason fromApiValue(String? value) {
    return values.firstWhere(
      (reason) => reason.apiValue == value,
      orElse: () => ReportReason.other,
    );
  }
}

/// Longest report description the backend accepts.
const int kReportDetailsMaxLength = 500;

/// Trims [details] and caps it at [kReportDetailsMaxLength] UTF-16 code units
/// (what the backend counts), without splitting an emoji's surrogate pair.
/// Returns null when nothing is left.
String? normalizeReportDetails(String? details) {
  final trimmed = details?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.length <= kReportDetailsMaxLength) return trimmed;

  var end = kReportDetailsMaxLength;
  final last = trimmed.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return trimmed.substring(0, end).trimRight();
}

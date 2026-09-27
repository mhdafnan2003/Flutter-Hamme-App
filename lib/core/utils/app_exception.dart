class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.code, this.details});

  final String message;
  final int? statusCode;

  /// Machine-readable backend error code (`details.code`), e.g.
  /// [AppErrorCodes.accountBanned].
  final String? code;

  /// Raw `details` payload of the backend error body, if any.
  final Object? details;

  /// The request field the backend rejected (`details.field`), if provided.
  String? get field {
    final details = this.details;
    return details is Map ? details['field']?.toString() : null;
  }

  /// The signed-in account (or this device) has been banned from Hamme.
  bool get isAccountBanned =>
      statusCode == 403 && code == AppErrorCodes.accountBanned;

  /// A name, username or social handle was rejected by the content filter;
  /// [message] is the user-facing explanation for [field].
  bool get isObjectionableContent => code == AppErrorCodes.objectionableContent;

  @override
  String toString() => message;
}

/// Error codes the backend sends in `details.code`.
abstract final class AppErrorCodes {
  static const String accountBanned = 'ACCOUNT_BANNED';
  static const String objectionableContent = 'OBJECTIONABLE_CONTENT';
  static const String voteBlocked = 'VOTE_BLOCKED';
}

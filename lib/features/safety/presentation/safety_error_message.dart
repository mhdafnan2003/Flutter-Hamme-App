import '../../../core/utils/app_exception.dart';

/// What to tell the user when a report, hide, block or unblock fails.
String safetyErrorMessage(Object error) {
  if (error is AppException) {
    final status = error.statusCode;
    final message = error.message.trim();
    if (status != null && status >= 500) {
      return 'Something went wrong on our side. Please try again.';
    }
    // 408 is the client-side timeout, whose message is meant for developers.
    if (status != 408 && message.isNotEmpty) return message;
  }
  return "Couldn't reach Hamme. Check your connection and try again.";
}

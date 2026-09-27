import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/fonts.dart';

enum AppSnackBarType { success, error, info }

/// Hamme's floating toast: a rounded card with a tinted icon badge, shown
/// in place of the default Material snack bar.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    showOn(
      ScaffoldMessenger.maybeOf(context),
      message,
      type: type,
      duration: duration,
    );
  }

  /// For callers that resolved the messenger before an `await`, when their
  /// own context may already be gone.
  static void showOn(
    ScaffoldMessengerState? messenger,
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (messenger == null || !messenger.mounted) return;
    final isDark = Theme.of(messenger.context).brightness == Brightness.dark;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: duration,
          content: _Toast(message: message, type: type, isDark: isDark),
        ),
      );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.message,
    required this.type,
    required this.isDark,
  });

  final String message;
  final AppSnackBarType type;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color accent) = switch (type) {
      AppSnackBarType.success => (
        Icons.check_rounded,
        TColors.hammePrimaryDark,
      ),
      AppSnackBarType.error => (Icons.priority_high_rounded, TColors.error),
      AppSnackBarType.info => (
        Icons.info_outline_rounded,
        TColors.hammePrimaryDark,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : TColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : TColors.hammeTrack),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: isDark ? TColors.white : TColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

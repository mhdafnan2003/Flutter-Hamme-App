import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Presents validation feedback in the platform's familiar alert style.
///
/// Returns `true` when the caller should carry out the primary action.
Future<bool> showOnboardingValidationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final platform = Theme.of(context).platform;
  final isCupertino =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isCupertino) {
    return await showCupertinoDialog<bool>(
          context: context,
          builder:
              (context) => CupertinoAlertDialog(
                title: Text(title),
                content: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(actionLabel),
                  ),
                ],
              ),
        ) ??
        false;
  }

  return await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              icon: const Icon(Icons.error_outline_rounded),
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(actionLabel),
                ),
              ],
            ),
      ) ??
      false;
}

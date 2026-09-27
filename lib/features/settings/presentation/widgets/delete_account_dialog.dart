import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _deleteMessage =
    'This permanently deletes your profile, photo, matches, and interactions. This cannot be undone. Active App Store subscriptions are not cancelled automatically.';

/// Asks the user to confirm permanent account deletion, in the platform's
/// alert style. Returns true when they chose to delete.
Future<bool> confirmAccountDeletion(BuildContext context) async {
  final isCupertino =
      Theme.of(context).platform == TargetPlatform.iOS ||
      Theme.of(context).platform == TargetPlatform.macOS;
  final confirmed =
      isCupertino
          ? await showCupertinoDialog<bool>(
            context: context,
            builder:
                (dialogContext) => CupertinoAlertDialog(
                  title: const Text('Delete account?'),
                  content: const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(_deleteMessage),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
          )
          : await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AlertDialog(
                  icon: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Delete account?'),
                  content: const Text(_deleteMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
          );
  return confirmed == true;
}

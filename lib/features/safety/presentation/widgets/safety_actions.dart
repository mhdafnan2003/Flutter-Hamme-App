import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/safety_providers.dart';
import '../../domain/models/report_result.dart';
import '../../domain/models/safety_target.dart';
import '../safety_error_message.dart';
import 'report_sheet.dart';

enum _SafetyAction { hide, report, block }

enum _Outcome { done, gone, failed }

/// Opens "Hide this vote / Report… / Block…" for [target] and runs the flow
/// the user picks.
///
/// The item leaves Play, Inbox and Matches as soon as the user confirms. If
/// the request then fails it comes back and the user is offered a retry.
/// [onRemoved] runs once the server has confirmed and this flow's sheets and
/// dialogs are closed — use it to leave a screen that shows the item.
Future<void> showSafetyActions(
  BuildContext context,
  SafetyTarget target, {
  VoidCallback? onRemoved,
}) async {
  // Resolve these up front: the card or row that opened the flow leaves the
  // tree as soon as its item is hidden.
  final controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(safetyControllerProvider.notifier);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);

  final action = await showCupertinoModalPopup<_SafetyAction>(
    context: context,
    builder:
        (sheetContext) => CupertinoActionSheet(
          title: Text(_sheetTitle(target)),
          actions: [
            if (target.canHide)
              CupertinoActionSheetAction(
                onPressed:
                    () => Navigator.of(sheetContext).pop(_SafetyAction.hide),
                child: const Text('Hide this vote'),
              ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed:
                  () => Navigator.of(sheetContext).pop(_SafetyAction.report),
              child: const Text('Report…'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed:
                  () => Navigator.of(sheetContext).pop(_SafetyAction.block),
              child: const Text('Block…'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
  );
  if (action == null || !navigator.mounted) return;

  switch (action) {
    case _SafetyAction.hide:
      final outcome = await _runWithRetry(
        navigator,
        failureTitle: "Couldn't hide this vote",
        run: () => controller.hide(target),
      );
      if (outcome == _Outcome.failed) return;
      onRemoved?.call();
      _showSnackBar(
        messenger,
        outcome == _Outcome.gone ? _goneMessage(target) : 'Vote hidden.',
      );

    case _SafetyAction.report:
      final outcome = await showReportSheet(navigator.context, target);
      if (outcome == null) return;
      onRemoved?.call();
      if (outcome.alreadyRemoved) {
        _showSnackBar(messenger, _goneMessage(target));
      } else if (navigator.mounted) {
        await _showReportConfirmation(
          navigator.context,
          blocked: outcome.blocked,
        );
      }

    case _SafetyAction.block:
      final confirmed = await _confirmBlock(navigator.context, target);
      if (!confirmed || !navigator.mounted) return;
      final outcome = await _runWithRetry(
        navigator,
        failureTitle: "Couldn't block ${target.subject}",
        run: () => controller.block(target),
      );
      if (outcome == _Outcome.failed) return;
      onRemoved?.call();
      _showSnackBar(
        messenger,
        outcome == _Outcome.gone
            ? _goneMessage(target)
            : 'Blocked. They can no longer vote for you.',
      );
  }
}

String _sheetTitle(SafetyTarget target) {
  final isMatch = target.matchId != null;
  if (target.anonymous) return isMatch ? 'Anonymous match' : 'Anonymous vote';
  final name = target.name;
  if (name == null) return isMatch ? 'Match' : 'Vote';
  return isMatch ? name : 'Vote from $name';
}

String _goneMessage(SafetyTarget target) {
  if (target.interactionId == null) return 'This person is no longer on Hamme.';
  return target.matchId == null
      ? 'This vote was already removed.'
      : 'This match was already removed.';
}

/// Runs [run] until it succeeds, the item turns out to be gone already, or the
/// user gives up after an error.
Future<_Outcome> _runWithRetry(
  NavigatorState navigator, {
  required String failureTitle,
  required Future<void> Function() run,
}) async {
  while (true) {
    try {
      await run();
      return _Outcome.done;
    } on SafetyTargetGoneException {
      return _Outcome.gone;
    } catch (error) {
      if (!navigator.mounted) return _Outcome.failed;
      final retry = await showCupertinoDialog<bool>(
        context: navigator.context,
        builder:
            (dialogContext) => CupertinoAlertDialog(
              title: Text(failureTitle),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(safetyErrorMessage(error)),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Try again'),
                ),
              ],
            ),
      );
      if (retry != true) return _Outcome.failed;
    }
  }
}

Future<bool> _confirmBlock(BuildContext context, SafetyTarget target) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder:
        (dialogContext) => CupertinoAlertDialog(
          title: Text('Block ${target.subject}?'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              "They won't be able to vote for you or match with you, and "
              "you won't see their votes. You can unblock them in Settings.",
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Block'),
            ),
          ],
        ),
  );
  return confirmed == true;
}

Future<void> _showReportConfirmation(
  BuildContext context, {
  required bool blocked,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder:
        (dialogContext) => CupertinoAlertDialog(
          title: const Text('Report sent'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                'Thanks for letting us know. Our team reviews every report '
                    'within 24 hours.',
                if (blocked) 'They can no longer vote for you.',
              ].join('\n\n'),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}

void _showSnackBar(ScaffoldMessengerState? messenger, String message) {
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Opens [url] outside the app, with a snack bar when that isn't possible.
Future<void> openExternalLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}

/// Opens a pre-filled email to Hamme support ([kSupportEmail]). When no mail
/// app can take it, the address is shown with a copy button instead, so
/// users can always reach us.
Future<void> emailSupport(
  BuildContext context, {
  required String subject,
  String? body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: _encodeMailQuery({
      'subject': subject,
      if (body != null && body.isNotEmpty) 'body': body,
    }),
  );
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    await showSupportEmailDialog(context);
  }
}

// `Uri.queryParameters` encodes spaces as '+', which mail apps show as is.
String _encodeMailQuery(Map<String, String> parameters) {
  return parameters.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
}

/// Shows the support address with a copy button.
Future<void> showSupportEmailDialog(BuildContext context) {
  const intro = "We couldn't open your mail app. Email us at:";
  final platform = Theme.of(context).platform;
  final isCupertino =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  Future<void> copyAddress(BuildContext dialogContext) async {
    try {
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    } catch (_) {
      // Copying is a convenience; the address stays visible either way.
    }
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email address copied.')));
    }
  }

  const address = SelectableText(
    kSupportEmail,
    textAlign: TextAlign.center,
    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
  );

  if (isCupertino) {
    return showCupertinoDialog<void>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: const Text('Contact Hamme'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(intro), SizedBox(height: 8), address],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => copyAddress(dialogContext),
                child: const Text('Copy email'),
              ),
            ],
          ),
    );
  }

  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          icon: const Icon(Icons.mail_outline_rounded),
          title: const Text('Contact Hamme'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(intro, textAlign: TextAlign.center),
              SizedBox(height: 8),
              address,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => copyAddress(dialogContext),
              child: const Text('Copy email'),
            ),
          ],
        ),
  );
}

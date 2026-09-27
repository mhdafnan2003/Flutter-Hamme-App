import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/safety_providers.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/report_result.dart';
import '../../domain/models/safety_target.dart';
import '../safety_error_message.dart';

/// How a submitted report sheet ended.
class ReportOutcome {
  const ReportOutcome({required this.blocked, this.alreadyRemoved = false});

  /// Whether the server blocked the sender.
  final bool blocked;

  /// The vote or person was already gone, so no report was filed.
  final bool alreadyRemoved;
}

/// Shows the report form for [target]: pick a reason, optionally add details,
/// choose whether to also block (on by default), then submit.
///
/// The item leaves the feeds as soon as the user submits. The sheet stays open
/// until the server confirms, so a failure can be retried without retyping.
/// Resolves to null if the user closes the sheet without reporting.
Future<ReportOutcome?> showReportSheet(
  BuildContext context,
  SafetyTarget target,
) {
  return showModalBottomSheet<ReportOutcome>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // Dragging would close the sheet even while a report is being sent; the
    // close button, the barrier and back are held off during a submit instead.
    enableDrag: false,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ReportSheet(target: target),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({required this.target, super.key});

  final SafetyTarget target;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final TextEditingController _details = TextEditingController();
  ReportReason? _reason;
  bool _block = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(safetyControllerProvider.notifier)
          .report(
            widget.target,
            reason: reason,
            details: _details.text,
            block: _block,
          );
      if (!mounted) return;
      Navigator.of(context).pop(ReportOutcome(blocked: result.blocked));
    } on SafetyTargetGoneException {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(const ReportOutcome(blocked: false, alreadyRemoved: true));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = safetyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          // useSafeArea only pads the top and sides; clear the home indicator.
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child:
                reason == null
                    ? _buildReasonStep(context)
                    : _buildDetailsStep(context, reason),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonStep(BuildContext context) {
    return Column(
      key: const ValueKey('report-reasons'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(onClose: () => Navigator.of(context).maybePop()),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Text(
            'Why are you reporting ${widget.target.subject}?',
            style: _titleStyle,
          ),
        ),
        _Panel(
          child: Column(
            children: [
              for (final reason in ReportReason.values) ...[
                if (reason != ReportReason.values.first)
                  const Divider(height: 1, indent: 18, endIndent: 18),
                _ReasonTile(
                  label: reason.label,
                  onTap: () => setState(() => _reason = reason),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(BuildContext context, ReportReason reason) {
    final subject = widget.target.subject;
    return Column(
      key: const ValueKey('report-details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          onBack: _submitting ? null : () => setState(() => _reason = null),
          onClose: _submitting ? null : () => Navigator.of(context).maybePop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Text(reason.label, style: _titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _details,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [_ReportDetailsLengthLimiter()],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Add details (optional)',
              hintStyle: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: TColors.darkGrey,
              ),
              counterText:
                  '${_details.text.length}/$kReportDetailsMaxLength',
              filled: true,
              fillColor: _panelColor(context),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: TColors.hammePrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Panel(
          child: SwitchListTile.adaptive(
            value: _block,
            onChanged:
                _submitting ? null : (value) => setState(() => _block = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            title: Text(
              'Also block $subject',
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              "They won't be able to vote for you or match with you.",
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: TColors.darkGrey,
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  color: TColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Your report wasn't sent. $_error",
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: TColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _SubmitButton(
            label: _error == null ? 'Submit report' : 'Try again',
            loading: _submitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: TFonts.nunito,
  fontWeight: FontWeight.w900,
  fontSize: 21,
  height: 1.25,
);

Color _panelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF242428)
        : TColors.hammeSurface;

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({this.onBack, this.onClose});

  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              icon: const Icon(CupertinoIcons.chevron_left, size: 22),
            )
          else
            const SizedBox(width: 48),
          const Expanded(
            child: Text(
              'Report',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            icon: const Icon(CupertinoIcons.xmark, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: TColors.darkGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.black : Colors.white;
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: dark ? Colors.white : Colors.black,
          foregroundColor: foreground,
          disabledBackgroundColor: dark ? Colors.white : Colors.black,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child:
            loading
                ? CupertinoActivityIndicator(color: foreground)
                : Text(
                  label,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: foreground,
                  ),
                ),
      ),
    );
  }
}

/// Caps the details at [kReportDetailsMaxLength] UTF-16 code units — what the
/// backend counts — where `maxLength` would count characters, letting emoji
/// push a report past the limit.
class _ReportDetailsLengthLimiter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= kReportDetailsMaxLength) return newValue;
    var end = kReportDetailsMaxLength;
    final last = newValue.text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    final text = newValue.text.substring(0, end);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

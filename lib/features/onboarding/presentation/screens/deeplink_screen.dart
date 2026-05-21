import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/providers/deferred_interaction_provider.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

class DeepLinkScreen extends ConsumerStatefulWidget {
  const DeepLinkScreen({super.key});

  @override
  ConsumerState<DeepLinkScreen> createState() => _DeepLinkScreenState();
}

class _DeepLinkScreenState extends ConsumerState<DeepLinkScreen> {
  final TextEditingController _linkController = TextEditingController();
  String _error = '';
  InteractionType? _selectedType;
  bool _autoHandledDeferredLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateFromDeferredLink();
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  InteractionType? _parseInteractionType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'crush':
        return InteractionType.crush;
      case 'friend':
        return InteractionType.friend;
      case 'frenemy':
        return InteractionType.frenemy;
      default:
        return null;
    }
  }

  ({String? shareCode, InteractionType? type, String? token}) _parseDeepLink(
    String input,
  ) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return (shareCode: null, type: null, token: null);
    }

    Uri? uri;
    if (trimmed.contains('://')) {
      uri = Uri.tryParse(trimmed);
    }

    if (uri != null) {
      if (uri.scheme == 'hamme' && uri.host == 'open') {
        final shareCode = uri.queryParameters['code'];
        final type = _parseInteractionType(uri.queryParameters['type']);
        final token = uri.queryParameters['token'];
        return (shareCode: shareCode, type: type, token: token);
      }

      if (uri.scheme == 'hamme' && uri.host == 'reveal') {
        final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        return (shareCode: null, type: null, token: token);
      }

      if (uri.scheme == 'https' && uri.host == 'app.hamme.link') {
        final segments = uri.pathSegments;
        if (segments.length >= 2 && segments[0] == 'u') {
          return (shareCode: segments[1], type: null, token: null);
        }
      }

      if (uri.scheme == 'https' && uri.host == AppConstants.appHost) {
        final segments = uri.pathSegments;
        if (segments.length >= 2 && segments[0] == 'u') {
          return (shareCode: segments[1], type: null, token: null);
        }
      }
    }

    // Treat as raw share code.
    return (shareCode: trimmed, type: null, token: null);
  }

  String? _buildDeferredLink({
    required String? shareCode,
    required InteractionType? type,
    required String? token,
  }) {
    if (token != null && token.isNotEmpty) {
      final params = <String, String>{'token': token};
      if (shareCode != null && shareCode.isNotEmpty) {
        params['code'] = shareCode;
      }
      if (type != null) {
        params['type'] = type.name;
      }
      final query = Uri(queryParameters: params).query;
      return 'hamme://open?$query';
    }

    if (shareCode != null && shareCode.isNotEmpty) {
      if (type == null) {
        return shareCode;
      }
      final query = Uri(
        queryParameters: {'code': shareCode, 'type': type.name},
      ).query;
      return 'hamme://open?$query';
    }

    return null;
  }

  void _hydrateFromDeferredLink() {
    if (_autoHandledDeferredLink) return;
    final token = ref.read(deferredInteractionTokenProvider);
    final shareCode = ref.read(deferredShareCodeProvider);
    final type = ref.read(deferredInteractionTypeProvider);

    final builtLink = _buildDeferredLink(
      shareCode: shareCode,
      type: type,
      token: token,
    );
    if (builtLink == null) return;

    _autoHandledDeferredLink = true;
    _linkController.text = builtLink;
    if (type != null) {
      setState(() => _selectedType = type);
    }
    _submit();
  }

  void _submit() {
    final parsed = _parseDeepLink(_linkController.text);
    if (parsed.token != null && parsed.token!.isNotEmpty) {
      ref.read(deferredInteractionTokenProvider.notifier).state = parsed.token;
      ref.read(deferredShareCodeProvider.notifier).state = parsed.shareCode;
      final resolvedType = parsed.type ?? _selectedType;
      ref.read(deferredInteractionTypeProvider.notifier).state = resolvedType;
      setState(() => _error = '');
      context.go('/onboarding/dob');
      return;
    }

    if (parsed.shareCode == null || parsed.shareCode!.isEmpty) {
      setState(() => _error = 'Enter a valid deep link, token, or share code.');
      return;
    }

    final resolvedType = parsed.type ?? _selectedType;
    if (resolvedType == null) {
      setState(() => _error = 'Pick a type or use a link that includes it.');
      return;
    }

    ref.read(deferredShareCodeProvider.notifier).state = parsed.shareCode;
    ref.read(deferredInteractionTypeProvider.notifier).state = resolvedType;
    ref.read(deferredInteractionTokenProvider.notifier).state = null;

    setState(() => _error = '');
    context.go('/onboarding/dob');
  }

  void _skip() {
    ref.read(deferredShareCodeProvider.notifier).state = null;
    ref.read(deferredInteractionTypeProvider.notifier).state = null;
    ref.read(deferredInteractionTokenProvider.notifier).state = null;
    setState(() => _error = '');
    context.go('/onboarding/dob');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to deferred values so hydration also works when link state arrives
    // slightly after first frame (common on app open from deep link).
    ref.watch(deferredInteractionTokenProvider);
    ref.watch(deferredShareCodeProvider);
    ref.watch(deferredInteractionTypeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hydrateFromDeferredLink();
      }
    });

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DobTopBar(onBack: () => context.go('/splash'), progress: 0.2),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Have a link from someone? Paste it here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: TColors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('🔗', style: TextStyle(fontSize: 28)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _linkController,
                autofocus: true,
                cursorColor: TColors.black,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: TColors.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Paste deep link or share code',
                  hintStyle: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: TColors.darkGrey,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: TColors.error,
                ),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Crush'),
                    selected: _selectedType == InteractionType.crush,
                    onSelected: (_) {
                      setState(() => _selectedType = InteractionType.crush);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Friend'),
                    selected: _selectedType == InteractionType.friend,
                    onSelected: (_) {
                      setState(() => _selectedType = InteractionType.friend);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Frenemy'),
                    selected: _selectedType == InteractionType.frenemy,
                    onSelected: (_) {
                      setState(() => _selectedType = InteractionType.frenemy);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: GradientButton(
                label: 'Continue',
                onTap: _submit,
              ),
            ),
            TextButton(
              onPressed: _skip,
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w800,
                  color: TColors.hammeMutedText,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

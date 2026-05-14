import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/providers/premium_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/avatar_bubble.dart';
import '../widgets/footer_link.dart';
import '../widgets/header_curve_clipper.dart';
import '../widgets/pro_feature.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  bool _isSubmitting = false;
  String? _errorText;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _continueToHome() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final draft = ref.read(onboardingDraftProvider).value;
    if (draft == null) {
      setState(() {
        _isSubmitting = false;
        _errorText = 'Onboarding data missing. Please try again.';
      });
      return;
    }

    try {
      final session = ref.read(authControllerProvider).value;
      if (session == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final age =
            draft.birthday == null
                ? 18
                : (DateTime.now().difference(draft.birthday!).inDays / 365.25).floor();
        debugPrint('[Onboarding] guest register begin');
        await ref.read(authControllerProvider.notifier).guestRegister(
          age: age.clamp(13, 100),
          displayName: (draft.name ?? 'Guest').trim(),
          username: (draft.username ?? 'user$now').trim(),
          instagramId:
              draft.socialPlatform?.toLowerCase().contains('instagram') == true
                  ? draft.username?.trim()
                  : null,
          snapchatId:
              draft.socialPlatform?.toLowerCase().contains('snapchat') == true
                  ? draft.username?.trim()
                  : null,
          avatarUrl: draft.profileImageUrl,
        );
        if (!mounted) return;
        final authState = ref.read(authControllerProvider);
        if (authState.hasError || authState.value == null) {
          throw authState.error ?? Exception('Guest registration failed');
        }
        debugPrint(
          '[Onboarding] guest register success: user=${authState.value?.user.id}',
        );
      } else {
        final dataSource = ProfileRemoteDataSource(ref.read(apiServiceProvider));
        await dataSource.updateMe(
          name: draft.name?.trim(),
          instagramId: draft.username?.trim(),
          username: draft.username?.trim(),
          profileImageUrl: draft.profileImageUrl,
        );
        if (!mounted) return;
        debugPrint('[Onboarding] existing session profile sync success');
      }

      debugPrint('[Onboarding] onboarding completion handled by auth flow');
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      debugPrint('Onboarding completion failed: $e');
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not complete setup. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumState = ref.watch(premiumControllerProvider).value;
    final isPro = premiumState?.isPro ?? false;
    final isBusy = premiumState?.isBusy ?? false;
    final message = premiumState?.message;
    final products = premiumState?.productDetails ?? const [];
    final productLabel =
        products.isNotEmpty ? '${products.first.price} / ${products.first.title}' : null;

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  ClipPath(
                    clipper: HeaderCurveClipper(),
                    child: Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            TColors.hammePrimary,
                            TColors.hammePrimaryDark,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 78,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Hamme',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: TColors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2),
                                color: TColors.black,
                              ),
                              Shadow(
                                offset: Offset(-2, 2),
                                color: TColors.black,
                              ),
                              Shadow(
                                offset: Offset(2, -2),
                                color: TColors.black,
                              ),
                              Shadow(
                                offset: Offset(-2, -2),
                                color: TColors.black,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: TColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: TColors.hammePrimaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 78,
                    right: 28,
                    child: GestureDetector(
                      onTap: _continueToHome,
                      child: const Icon(
                        Icons.close_rounded,
                        color: TColors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 34),
                    const Text(
                      'Unlock Unlimited\nAccess',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TFonts.nunito,
                        fontSize: 28,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: TColors.hammePrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TColors.hammePrimaryDark),
                      ),
                      child: const Column(
                        children: [
                          ProFeature(
                            icon: 'UNL',
                            title: 'Unlimited Play',
                            subtitle:
                                'No waiting, Play every profile,\nanytime.',
                          ),
                          SizedBox(height: 28),
                          ProFeature(
                            icon: 'REV',
                            title: 'Unlimited Rewinds',
                            subtitle:
                                'Picked wrong? Go back and change\nyour pick.',
                          ),
                          SizedBox(height: 28),
                          ProFeature(
                            icon: 'VIP',
                            title: 'Priority Profile',
                            subtitle:
                                'Appear first in queues of people you\nreacted to.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AvatarBubble(label: 'N', color: Color(0xFFFA3F8F)),
                        AvatarBubble(label: 'K', color: Color(0xFF1BD66B)),
                        AvatarBubble(label: 'A', color: Color(0xFF3FA7FF)),
                        AvatarBubble(label: 'S', color: Color(0xFFFFCB36)),
                        AvatarBubble(label: 'R', color: Color(0xFFFF5252)),
                        SizedBox(width: 10),
                        Text(
                          '1000+ went PRO today',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: TColors.darkGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (isPro)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF5E8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2D9A59)),
                        ),
                        child: const Text(
                          'PRO is active on this device/account.',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A6C3D),
                          ),
                        ),
                      ),
                    if (productLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          productLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: TFonts.nunito,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TColors.darkGrey,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            isBusy
                                ? null
                                : () => ref
                                    .read(premiumControllerProvider.notifier)
                                    .purchasePro(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: TColors.hammePrimaryDark,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Subscribe via Google Play',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w800,
                            color: TColors.hammePrimaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed:
                            isBusy
                                ? null
                                : () => ref
                                    .read(premiumControllerProvider.notifier)
                                    .restorePurchases(),
                        child: const Text(
                          'Restore Purchases',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w800,
                            color: TColors.hammePrimaryDark,
                          ),
                        ),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: TColors.darkGrey,
                        ),
                      ),
                    ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDDDDD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Debug Premium Override',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w800,
                                color: TColors.hammePrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _manualController,
                              decoration: const InputDecoration(
                                hintText: 'Type true, false, or clear',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      final text =
                                          _manualController.text.trim().toLowerCase();
                                      if (text == 'true') {
                                        ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .setManualOverride(true);
                                      } else if (text == 'false') {
                                        ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .setManualOverride(false);
                                      } else {
                                        ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .setManualOverride(null);
                                      }
                                    },
                                    child: const Text('Apply'),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed:
                                        () => ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .setManualOverride(null),
                                    child: const Text('Clear Override'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        () => ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .debugVerifyMockPurchase(active: true),
                                    child: const Text('Mock Backend PRO'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        () => ref
                                            .read(
                                              premiumControllerProvider.notifier,
                                            )
                                            .debugVerifyMockPurchase(active: false),
                                    child: const Text('Mock Backend OFF'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GradientButton(
                      label: 'Continue',
                      onTap: _isSubmitting ? () {} : _continueToHome,
                    ),
                    if (_isSubmitting) ...[
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(strokeWidth: 2),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'pro renews for \$6.99/wk',
                      style: TextStyle(
                        fontFamily: TFonts.nunito,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: TColors.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const FooterLink(label: 'Privacy'),
                        GestureDetector(
                          onTap:
                              () => ref
                                  .read(premiumControllerProvider.notifier)
                                  .restorePurchases(),
                          child: const FooterLink(label: 'Restore'),
                        ),
                        const FooterLink(label: 'Terms'),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

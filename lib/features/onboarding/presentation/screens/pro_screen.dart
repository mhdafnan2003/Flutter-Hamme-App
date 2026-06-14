import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import '../widgets/avatar_bubble.dart';
import '../widgets/footer_link.dart';
import '../widgets/header_curve_clipper.dart';
import '../widgets/pro_feature.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key, this.isOnboarding = true});

  /// When false, the screen acts as a standalone upgrade page reachable from
  /// the profile. It will not run onboarding/guest-register logic and will pop
  /// back instead of navigating to home.
  final bool isOnboarding;

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  bool _isSubmitting = false;
  String? _errorText;

  /// The top-right close button. In the upgrade flow it simply dismisses the
  /// paywall; during onboarding it proceeds (skips Pro) to the home screen.
  Future<void> _dismiss() async {
    if (!widget.isOnboarding) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }
    await _completeOnboarding();
  }

  /// Starts a real in-app purchase for the Pro subscription.
  Future<void> _buyPro() async {
    await ref.read(billingControllerProvider.notifier).buyPro();
  }

  /// Onboarding-only: finalize registration / profile sync, then go home.
  Future<void> _completeOnboarding() async {
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
        if (!mounted) return;        final authState = ref.read(authControllerProvider);
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
          avatarUrl: draft.profileImageUrl,
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
        _errorText = e is AppException
            ? e.message
            : 'Could not complete setup. Please try again.';
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
    final billing = ref.watch(billingControllerProvider);
    final isUpgrade = !widget.isOnboarding;

    // When the Pro entitlement is granted (purchase or restore succeeds),
    // dismiss the paywall.
    ref.listen<bool>(isProProvider, (previous, next) {
      if (next == true && (previous != true)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now Pro! 🎉')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    });

    // The big CTA performs a real purchase in the upgrade flow and just
    // continues onboarding otherwise.
    final bool ctaBusy = isUpgrade ? billing.busy : _isSubmitting;
    final String ctaLabel = isUpgrade
        ? (billing.proProduct != null
              ? 'Subscribe • ${billing.proProduct!.price}'
              : 'Upgrade to Pro')
        : 'Continue';
    final Future<void> Function() onCta = isUpgrade ? _buyPro : _completeOnboarding;
    final String? errorText = _errorText ?? (isUpgrade ? billing.error : null);

    return Scaffold(
      backgroundColor: TColors.white,
      body: Column(
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                ClipPath(
                  clipper: HeaderCurveClipper(),
                  child: Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF9E57FF),
                          Color(0xFF8840FF),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Hammepro logo.png',
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 46,
                  right: 24,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close_rounded,
                      color: TColors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    'Unlock Unlimited\nAccess 🔒',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFCE00E6),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2DBFF),
                        width: 1.5,
                      ),
                    ),
                    child: const Column(
                      children: [
                        SizedBox(height: 30),
                        ProFeature(
                          icon: Image(
                            image: AssetImage('assets/icons/Infinity.png'),
                            width: 28,
                            height: 28,
                          ),
                          title: 'Unlimited Play',
                          subtitle:
                              'No waiting, Play every profile,\nanytime.',
                        ),
                        SizedBox(height: 30),
                        ProFeature(
                          icon: Image(
                            image: AssetImage(
                              'assets/icons/Right Arrow Curving Left.png',
                            ),
                            width: 28,
                            height: 28,
                          ),
                          title: 'Unlimited Rewinds',
                          subtitle:
                              'Picked wrong? Go back and change\nyour pick.',
                        ),
                       SizedBox(height: 30),
                        ProFeature(
                          icon: Image(
                            image: AssetImage('assets/icons/High Voltage.png'),
                            width: 28,
                            height: 28,
                          ),
                          title: 'Priority Profile',
                          subtitle:
                              'Appear first in queues of people you\nreacted to.',
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AvatarBubble(label: 'N', color: Color(0xFFFA3F8F)),
                      AvatarBubble(label: 'K', color: Color(0xFF1BD66B)),
                      AvatarBubble(label: 'A', color: Color(0xFF3FA7FF)),
                      AvatarBubble(label: 'S', color: Color(0xFFFFCB36)),
                      AvatarBubble(label: 'R', color: Color(0xFFFF5252)),
                      SizedBox(width: 12),
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
                  const Spacer(flex: 1),
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF9E57FF),
                          Color(0xFF8B44FF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9E57FF).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: ctaBusy ? () {} : () => onCta(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                      ),
                      child: ctaBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              ctaLabel,
                              style: const TextStyle(
                                fontFamily: TFonts.nunito,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(flex: 1),
                  Text(
                    billing.proProduct != null
                        ? 'pro renews for ${billing.proProduct!.price}/wk'
                        : 'pro renews for \$6.99/wk',
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: TColors.darkGrey,
                    ),
                  ),
                  const Spacer(flex: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const FooterLink(label: 'Privacy'),
                      FooterLink(
                        label: 'Restore',
                        onTap: () => ref
                            .read(billingControllerProvider.notifier)
                            .restorePurchases(),
                      ),
                      const FooterLink(label: 'Terms'),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

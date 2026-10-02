import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/core/utils/link_launcher.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

import '../widgets/avatar_bubble.dart';
import '../widgets/footer_link.dart';
import '../widgets/pro_feature.dart';
import 'package:hamme_app/utils/popups/app_snack_bar.dart';

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
  bool _isRestoringProfile = false;
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

  /// Onboarding Continue: starts the real purchase (it resolves later via
  /// the billing stream, independently of this screen) and finishes
  /// onboarding regardless of the purchase outcome. Buying Pro and
  /// finishing signup are separate concerns — same as the X (skip) button
  /// already treats them.
  Future<void> _continueOnboardingWithPurchase() async {
    await _buyPro();
  }

  Future<void> _uploadSelectedProfileImageInBackground() async {
    final selectedImage = ref.read(onboardingProfileImageProvider);
    if (selectedImage == null) {
      debugPrint(
        '[Onboarding] profile image upload skipped: no image selected',
      );
      return;
    }

    debugPrint(
      '[Onboarding] profile image upload begin: ${selectedImage.filename} '
      '(${selectedImage.bytes.length} bytes)',
    );

    final apiService = ref.read(apiServiceProvider);
    final draftNotifier = ref.read(onboardingDraftProvider.notifier);
    final imageNotifier = ref.read(onboardingProfileImageProvider.notifier);
    final authController = ref.read(authControllerProvider.notifier);
    try {
      final imageUrl = await UploadRemoteDataSource(
        apiService,
      ).uploadProfileImageBytes(
        bytes: selectedImage.bytes,
        filename: selectedImage.filename,
      );
      // PATCH /profiles/me returns the updated user, so no refetch is needed.
      final updatedUser = await ProfileRemoteDataSource(
        apiService,
      ).updateMe(avatarUrl: imageUrl);
      await draftNotifier.setProfileImageUrl(imageUrl);
      imageNotifier.state = null;
      authController.setUser(updatedUser);
      debugPrint('[Onboarding] profile image upload success');
    } catch (error) {
      // Home keeps the local preview. A later profile-page edit can retry.
      debugPrint('[Onboarding] background profile image upload failed: $error');
    }
  }

  Future<void> _restoreProProfile() async {
    if (_isRestoringProfile) return;
    setState(() {
      _isRestoringProfile = true;
      _errorText = null;
    });

    try {
      final purchaseRestored =
          await ref.read(billingControllerProvider.notifier).restorePurchases();
      if (!purchaseRestored || !mounted) return;

      if (widget.isOnboarding) {
        await _completeOnboarding();
      } else if (mounted) {
        _showRestored();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText =
            error is AppException
                ? error.message
                : 'Could not restore Pro. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isRestoringProfile = false);
      }
    }
  }

  void _showRestored() {
    AppSnackBar.show(
      context,
      'Pro restored to this profile.',
      type: AppSnackBarType.success,
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _confirmSubscriptionRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Restore your Pro subscription?'),
            content: const Text(
              'An active Pro subscription was found on your store account. Link it to this Hamme profile? If it is linked to another profile, Pro access will move here. Your old profile and its data will not be restored. You will not be charged again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore Pro'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    final controller = ref.read(billingControllerProvider.notifier);
    if (confirmed != true) {
      controller.dismissRestore();
      return;
    }
    setState(() => _isRestoringProfile = true);
    final restored = await controller.confirmRestore();
    if (!mounted) return;
    setState(() => _isRestoringProfile = false);
    if (restored) {
      if (widget.isOnboarding) {
        await _completeOnboarding();
      } else {
        _showRestored();
      }
    }
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
      if (ref.read(authControllerProvider).value == null) {
        throw const AppException('Your account is still being created.');
      }

      // The photo is optional and can finish after Home has opened. Account
      // creation is still awaited because the protected upload needs its token.
      unawaited(_uploadSelectedProfileImageInBackground());

      await ref.read(onboardingCompletionProvider.notifier).markComplete();
      debugPrint('[Onboarding] onboarding marked complete');
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      debugPrint('Onboarding completion failed: $e');
      if (!mounted) return;
      setState(() {
        _errorText =
            e is AppException
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
    final headerHeight = 156.0;
    // The design places the footer just above the home-indicator area rather
    // than adding a second bottom inset below an already padded footer.
    final footerBottomPadding = (MediaQuery.paddingOf(context).bottom - 5)
        .clamp(20.0, double.infinity);

    ref.listen<bool>(
      billingControllerProvider.select((s) => s.restoreRequired),
      (previous, next) {
        if (next && previous != true) unawaited(_confirmSubscriptionRestore());
      },
    );

    // A new Pro purchase can dismiss the paywall. A restored purchase goes
    // through the explicit confirmation flow to link this profile.
    ref.listen<bool>(isProProvider, (previous, next) {
      if (next == true && (previous != true)) {
        if (_isRestoringProfile ||
            ref.read(billingControllerProvider).restoreRequired) {
          return;
        }
        if (!mounted) return;
        AppSnackBar.show(
          context,
          'You are now Pro! 🎉',
          type: AppSnackBarType.success,
        );
        if (widget.isOnboarding) {
          unawaited(_completeOnboarding());
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    });

    // The big CTA performs a real purchase in the upgrade flow and just
    // continues onboarding otherwise.
    final bool ctaBusy = billing.busy || _isSubmitting || _isRestoringProfile;
    final String ctaLabel = 'Continue';
    final Future<void> Function() onCta =
        isUpgrade ? _buyPro : _continueOnboardingWithPurchase;
    final String? errorText = _errorText ?? billing.error;

    return Scaffold(
      backgroundColor: TColors.white,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: headerHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SvgPicture.asset(
                        TImages.proHeaderCurve,
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned(
                      top: 78,
                      left: MediaQuery.sizeOf(context).width / 2 - 46.5,
                      child: Image.asset(
                        TImages.proHammeLogo,
                        width: 143,
                        height: 38,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      top: 72,
                      right: 24,
                      child: GestureDetector(
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Opacity(
                            opacity: 0.6,
                            child: Center(
                              child: SvgPicture.asset(
                                TImages.proClose,
                                width: 17,
                                height: 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const horizontalPadding = 28.0;
                      const referenceGapTotal = 156.0;
                      // Use a compact composition on shorter phones so the
                      // plan details and pinned legal actions fit together.
                      final compact = constraints.maxHeight < 560;
                      final titleHeight = compact ? 60.0 : 76.0;
                      final featureCardHeight = compact ? 214.0 : 308.0;
                      final featurePadding = compact ? 16.0 : 23.0;
                      final featureRowHeight = compact ? 52.0 : 62.0;
                      final featureGap = compact ? 12.0 : 38.0;
                      final lastFeatureGap = compact ? 12.0 : 36.0;
                      final ctaHeight = compact ? 56.0 : 62.0;
                      final billingHeight = 22.0;
                      final fixedContentHeight =
                          titleHeight +
                          featureCardHeight +
                          24 +
                          ctaHeight +
                          billingHeight;
                      final footerHeight = 19.0 + footerBottomPadding;
                      final gapScale = ((constraints.maxHeight -
                                  fixedContentHeight -
                                  footerHeight) /
                              referenceGapTotal)
                          .clamp(0.0, 1.25);

                      double gap(double referenceValue) =>
                          referenceValue * gapScale;
                      final ctaWidth =
                          (MediaQuery.sizeOf(context).width - 48)
                              .clamp(0.0, 345.0)
                              .toDouble();

                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight:
                                      constraints.maxHeight - footerHeight,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(height: gap(40)),
                                      SizedBox(
                                        height: titleHeight,
                                        child: const _UnlockTitle(),
                                      ),
                                      SizedBox(height: gap(32)),
                                      Container(
                                        width: double.infinity,
                                        height: featureCardHeight,
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          featurePadding,
                                          12,
                                          featurePadding,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEBEAFA),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF9B6AFF),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              height: featureRowHeight,
                                              child: ProFeature(
                                                icon: _UnlimitedPlayIcon(),
                                                title: 'Unlimited Play',
                                                subtitle:
                                                    'No waiting, Play every profile,\nanytime.',
                                              ),
                                            ),
                                            SizedBox(height: featureGap),
                                            SizedBox(
                                              height: featureRowHeight,
                                              child: ProFeature(
                                                icon: Image(
                                                  image: AssetImage(
                                                    TImages.proRewind,
                                                  ),
                                                  width: 32,
                                                  height: 32,
                                                  filterQuality:
                                                      FilterQuality.high,
                                                ),
                                                title: 'Unlimited Rewinds',
                                                subtitle:
                                                    'Picked wrong? Go back and change\nyour pick.',
                                              ),
                                            ),
                                            SizedBox(height: lastFeatureGap),
                                            SizedBox(
                                              height: featureRowHeight,
                                              child: ProFeature(
                                                icon: Image(
                                                  image: AssetImage(
                                                    TImages.proHighVoltage,
                                                  ),
                                                  width: 32,
                                                  height: 32,
                                                  filterQuality:
                                                      FilterQuality.high,
                                                ),
                                                title: 'Priority Profile',
                                                subtitle:
                                                    'Appear first in queues of people you\nreacted to.',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: gap(40)),
                                      const SizedBox(
                                        height: 24,
                                        child: _ProSocialProof(),
                                      ),
                                      SizedBox(height: gap(14)),
                                      SizedBox(
                                        height: ctaHeight,
                                        child: OverflowBox(
                                          minWidth: ctaWidth,
                                          maxWidth: ctaWidth,
                                          minHeight: ctaHeight,
                                          maxHeight: ctaHeight,
                                          child: SizedBox(
                                            width: ctaWidth,
                                            height: ctaHeight,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(33),
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Color(0xFF9F6FFF),
                                                    Color(0xFF7838FE),
                                                  ],
                                                ),
                                              ),
                                              child: ElevatedButton(
                                                onPressed:
                                                    ctaBusy
                                                        ? () {}
                                                        : () => onCta(),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  padding: EdgeInsets.zero,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          33,
                                                        ),
                                                  ),
                                                ),
                                                child:
                                                    isUpgrade && ctaBusy
                                                        ? const SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                        : Text(
                                                          ctaLabel,
                                                          style:
                                                              const TextStyle(
                                                                fontFamily:
                                                                    TFonts
                                                                        .nunito,
                                                                fontSize: 20,
                                                                height: 27 / 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: Color(
                                                                  0xFFFBFBFB,
                                                                ),
                                                              ),
                                                        ),
                                              ),
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
                                      SizedBox(height: gap(12)),
                                      SizedBox(
                                        height: 22,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            billing.proProduct != null
                                                ? 'pro renews for ${billing.proProduct!.price}/wk'
                                                : 'pro renews for \$6.99/wk',
                                            style: const TextStyle(
                                              fontFamily: TFonts.nunito,
                                              fontSize: 16,
                                              height: 22 / 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF98999A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: gap(18)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 19,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 44,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FooterLink(
                                      label: 'Privacy',
                                      onTap:
                                          () => openExternalLink(
                                            context,
                                            kPrivacyPolicyUrl,
                                          ),
                                    ),
                                  ),
                                  FooterLink(
                                    label: 'Restore',
                                    onTap:
                                        billing.busy || _isRestoringProfile
                                            ? null
                                            : _restoreProProfile,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FooterLink(
                                      label: 'Terms',
                                      onTap:
                                          () => openExternalLink(
                                            context,
                                            kTermsOfUseUrl,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: footerBottomPadding),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnlockTitle extends StatelessWidget {
  const _UnlockTitle();

  static const _titleStyle = TextStyle(
    fontFamily: TFonts.nunito,
    fontSize: 28,
    height: 38 / 28,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [Color(0xFF9000FF), Color(0xFFD200BD)],
              ).createShader(bounds);
            },
            child: const Text(
              'Unlock Unlimited',
              textAlign: TextAlign.center,
              style: _titleStyle,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFF9000FF), Color(0xFFD200BD)],
                  ).createShader(bounds);
                },
                child: const Text('Access ', style: _titleStyle),
              ),
              Image.asset(
                TImages.proUnlocked,
                width: 28,
                height: 28,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnlimitedPlayIcon extends StatelessWidget {
  const _UnlimitedPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      TImages.proInfinity,
      width: 32,
      height: 32,
      filterQuality: FilterQuality.high,
    );
  }
}

class _ProSocialProof extends StatelessWidget {
  const _ProSocialProof();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 104,
            height: 24,
            child: Stack(
              children: const [
                Positioned(
                  left: 0,
                  child: AvatarBubble(label: 'N', color: Color(0xFFFF457E)),
                ),
                Positioned(
                  left: 20,
                  child: AvatarBubble(
                    label: 'K',
                    color: Color(0xFF30E584),
                    showBorder: true,
                  ),
                ),
                Positioned(
                  left: 40,
                  child: AvatarBubble(
                    label: 'A',
                    color: Color(0xFF4694FF),
                    showBorder: true,
                  ),
                ),
                Positioned(
                  left: 60,
                  child: AvatarBubble(
                    label: 'S',
                    color: Color(0xFFFFDB45),
                    showBorder: true,
                  ),
                ),
                Positioned(
                  left: 80,
                  child: AvatarBubble(
                    label: 'R',
                    color: Color(0xFFFF5353),
                    showBorder: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '1000+ went PRO today',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB2B2B2),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
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
      await ProfileRemoteDataSource(apiService).updateMe(avatarUrl: imageUrl);
      await draftNotifier.setProfileImageUrl(imageUrl);
      imageNotifier.state = null;
      await authController.refreshUser();
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
      if (!purchaseRestored) return;

      final restored =
          await ref.read(authControllerProvider.notifier).restoreProProfile();
      if (!restored) {
        throw const AppException(
          'No saved Pro profile was found on this device.',
        );
      }
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText =
            error is AppException
                ? error.message
                : 'Could not restore your Pro profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isRestoringProfile = false);
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final headerHeight = 156.0;
    final footerBottomPadding =
        bottomInset > 0 ? (bottomInset - 5).clamp(20.0, 29.0) : 20.0;

    // A new Pro purchase can dismiss the paywall. A restored purchase goes
    // through _restoreProProfile so its old profile is restored explicitly.
    ref.listen<bool>(isProProvider, (previous, next) {
      if (next == true && (previous != true)) {
        if (_isRestoringProfile) return;
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You are now Pro! 🎉')));
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
    final String ctaLabel = 'Continue';
    final Future<void> Function() onCta =
        isUpgrade ? _buyPro : _completeOnboarding;
    final String? errorText = _errorText ?? (isUpgrade ? billing.error : null);

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
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          TImages.proHammeLogo,
                          width: 144,
                          height: 38,
                          filterQuality: FilterQuality.high,
                        ),
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
                      final horizontalPadding = 28.0;
                      const minimumContentHeight = 570.0;
                      final contentHeight =
                          constraints.maxHeight < minimumContentHeight
                              ? minimumContentHeight
                              : constraints.maxHeight;

                      return SingleChildScrollView(
                        child: SizedBox(
                          height: contentHeight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              children: [
                                const Spacer(flex: 2),
                                const _UnlockTitle(),
                                const Spacer(flex: 2),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    24,
                                    12,
                                    22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBEAFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF9B6AFF),
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      ProFeature(
                                        icon: _UnlimitedPlayIcon(),
                                        title: 'Unlimited Play',
                                        subtitle:
                                            'No waiting, Play every profile,\nanytime.',
                                      ),
                                      SizedBox(height: 24),
                                      ProFeature(
                                        icon: Text(
                                          '↩️',
                                          style: TextStyle(fontSize: 32),
                                        ),
                                        title: 'Unlimited Rewinds',
                                        subtitle:
                                            'Picked wrong? Go back and change\nyour pick.',
                                      ),
                                      SizedBox(height: 24),
                                      ProFeature(
                                        icon: Text(
                                          '⚡️',
                                          style: TextStyle(fontSize: 32),
                                        ),
                                        title: 'Priority Profile',
                                        subtitle:
                                            'Appear first in queues of people you\nreacted to.',
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(flex: 3),
                                const _ProSocialProof(),
                                const Spacer(flex: 1),
                                Container(
                                  width: double.infinity,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(33),
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
                                    onPressed: ctaBusy ? () {} : () => onCta(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(33),
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
                                              style: const TextStyle(
                                                fontFamily: TFonts.nunito,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFFBFBFB),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF98999A),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: FooterLink(
                                          label: 'Privacy',
                                          onTap: () async {
                                            final url = Uri.parse(
                                              'https://www.hamme.app/privacy-policy',
                                            );
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode:
                                                    LaunchMode
                                                        .externalApplication,
                                              );
                                            }
                                          },
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
                                          onTap: () async {
                                            final url = Uri.parse(
                                              'https://www.hamme.app/terms-of-service',
                                            );
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode:
                                                    LaunchMode
                                                        .externalApplication,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: footerBottomPadding),
                              ],
                            ),
                          ),
                        ),
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
    height: 1.15,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _UnlimitedPlayIcon extends StatelessWidget {
  const _UnlimitedPlayIcon();

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const Image(
        image: AssetImage('assets/icons/loop.png'),
        width: 32,
        height: 32,
        filterQuality: FilterQuality.high,
      );
    }

    return const Text(
      '♾️',
      style: TextStyle(fontSize: 32),
    );
  }
}

class _ProSocialProof extends StatelessWidget {
  const _ProSocialProof();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 104,
          height: 26,
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
            fontWeight: FontWeight.w800,
            color: Color(0xFFB2B2B2),
          ),
        ),
      ],
    );
  }
}

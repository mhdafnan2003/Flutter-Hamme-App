import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
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
                      'Unlock Unlimited\nAccess 🔒',
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
                            icon: '∞',
                            title: 'Unlimited Play',
                            subtitle:
                                'No waiting, Play every profile,\nanytime.',
                          ),
                          SizedBox(height: 28),
                          ProFeature(
                            icon: '↩',
                            title: 'Unlimited Rewinds',
                            subtitle:
                                'Picked wrong? Go back and change\nyour pick.',
                          ),
                          SizedBox(height: 28),
                          ProFeature(
                            icon: '⚡',
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FooterLink(label: 'Privacy'),
                        FooterLink(label: 'Restore'),
                        FooterLink(label: 'Terms'),
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

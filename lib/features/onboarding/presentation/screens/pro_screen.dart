import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import '../../../../../core/widgets/gradient_button.dart';

class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  Future<void> _continueToHome(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingCompletionProvider.notifier).markComplete();
    if (!context.mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    clipper: _HeaderCurveClipper(),
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
                      onTap: () => _continueToHome(context, ref),
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
                          _ProFeature(
                            icon: '∞',
                            title: 'Unlimited Play',
                            subtitle:
                                'No waiting, Play every profile,\nanytime.',
                          ),
                          SizedBox(height: 28),
                          _ProFeature(
                            icon: '↩',
                            title: 'Unlimited Rewinds',
                            subtitle:
                                'Picked wrong? Go back and change\nyour pick.',
                          ),
                          SizedBox(height: 28),
                          _ProFeature(
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
                        _AvatarBubble(label: 'N', color: Color(0xFFFA3F8F)),
                        _AvatarBubble(label: 'K', color: Color(0xFF1BD66B)),
                        _AvatarBubble(label: 'A', color: Color(0xFF3FA7FF)),
                        _AvatarBubble(label: 'S', color: Color(0xFFFFCB36)),
                        _AvatarBubble(label: 'R', color: Color(0xFFFF5252)),
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
                      onTap: () => _continueToHome(context, ref),
                    ),
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
                        _FooterLink(label: 'Privacy'),
                        _FooterLink(label: 'Restore'),
                        _FooterLink(label: 'Terms'),
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

class _ProFeature extends StatelessWidget {
  const _ProFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: TColors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            icon,
            style: const TextStyle(
              fontSize: 32,
              color: TColors.hammePrimaryDark,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: TColors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: TColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: TColors.white,
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: TFonts.nunito,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: TColors.darkGrey,
      ),
    );
  }
}

class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 12)
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        size.width,
        size.height - 12,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

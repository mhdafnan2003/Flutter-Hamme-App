import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final draft = ref.watch(onboardingDraftProvider).value;
    final isPro = ref.watch(isProProvider);

    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Your Profile';
    final handle = user?.instagramId.isNotEmpty ?? false
        ? user!.instagramId
        : (user?.shareCode != null ? '@${user!.shareCode}' : '');

    // The uploaded image URL is reliably stored in the onboarding draft, so we
    // prefer the account image and fall back to the draft (same source the
    // home card uses).
    final profileImageUrl =
        (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
            ? user.avatarUrl
            : draft?.profileImageUrl;
    final hasProfileImage = profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.left_chevron,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(TImages.hammeHomeLogo, height: 32),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Avatar ────────────────────────────────────────────────────
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TColors.hammePrimary, width: 3),
                color: TColors.hammeSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasProfileImage
                  ? Image.network(profileImageUrl, fit: BoxFit.cover)
                  : const Icon(
                      CupertinoIcons.person_solid,
                      size: 56,
                      color: TColors.grey,
                    ),
            ),

            const SizedBox(height: 16),

            Text(
              name,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: TColors.black,
              ),
            ),
            if (handle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                handle,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: TColors.darkGrey,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Plan status ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isPro ? const Color(0xFFF1F0FD) : TColors.hammeSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPro ? const Color(0xFF9E57FF) : TColors.grey,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    size: 16,
                    color: isPro ? const Color(0xFF9E57FF) : TColors.darkGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPro ? 'Pro Plan' : 'Free Plan',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isPro ? const Color(0xFF8B44FF) : TColors.darkerGrey,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Upgrade to Pro ────────────────────────────────────────────
            if (!isPro)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => context.push('/pro'),
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9E57FF), Color(0xFF8B44FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9E57FF).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.star_fill, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to Pro',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

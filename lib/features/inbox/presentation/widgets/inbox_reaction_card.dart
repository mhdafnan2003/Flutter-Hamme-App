import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class InboxReactionCard extends StatelessWidget {
  const InboxReactionCard({
    required this.variation,
    required this.count,
    this.imageUrl,
    super.key,
  });

  final InboxVariation variation;
  final int count;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Avatar circle diameter and how much it overhangs above the card
    const double avatarSize = 110;
    const double avatarOverhang = avatarSize / 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ── Outer Card with Fixed Height ────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: avatarOverhang),
            width: double.infinity,
            height: 260, // Further reduced height
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: variation.borderColor, width: 8),
              borderRadius: BorderRadius.circular(52),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6), // The white gap
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: variation.gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(42),
              ),
              padding: const EdgeInsets.only(
                top: 40,
                bottom: 6,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Count number
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w900,
                      fontSize: 56, // Reduced from 60
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle
                  Text(
                    count == 1
                        ? '1 person has ${variation.typeKey} on you'
                        : '$count people have ${variation.typeKey} on you',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 14, // Reduced from 16
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tagline pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      variation.tagline,
                      style: const TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w800,
                        fontSize: 13, // Reduced from 14
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating Avatar ───────────────────────────────────────────────
          Positioned(
            top: 0,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // White ring then border-color ring
                border: Border.all(color: TColors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: variation.borderColor, width: 3),
                ),
                child: ClipOval(
                  child: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            CupertinoIcons.person_solid,
                            size: 52,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.person_solid,
                          size: 52,
                          color: Colors.grey,
                        ),
                ),
              ),
            ),
          ),

          // ── Emoji Badge (overlaps bottom of avatar) ───────────────────────
          Positioned(
            top: avatarSize - 26,   // sits at the very bottom of the avatar
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  variation.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

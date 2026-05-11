import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class InboxReactionCard extends StatelessWidget {
  const InboxReactionCard({required this.variation, required this.count, super.key});

  final InboxVariation variation;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 58),
            decoration: BoxDecoration(
              color: TColors.white,
              border: Border.all(color: variation.borderColor, width: 8),
              borderRadius: BorderRadius.circular(48),
            ),
            padding: const EdgeInsets.all(8),
            child: Container(
              width: double.infinity,
              height: 230,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: variation.gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w900,
                      fontSize: 48,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      count == 0
                          ? TTexts.inboxHint
                          : count == 1
                              ? 'New ${variation.emoji} reaction'
                              : 'New ${variation.emoji} reactions',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TColors.hammeSurface,
                border: Border.all(color: TColors.white, width: 6),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: variation.borderColor, width: 3),
                ),
                child: const Icon(
                  CupertinoIcons.person_solid,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  variation.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

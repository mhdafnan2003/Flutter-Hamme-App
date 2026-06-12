import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'match_success_overlay.dart' show MatchAvatar;

/// Shown to the original voter (Person A who voted via share link) when
/// Creator B votes back but it is NOT a match.
class PollNotAMatchOverlay extends StatelessWidget {
  const PollNotAMatchOverlay({
    super.key,
    required this.interaction,
    required this.currentUserImageUrl,
    required this.onDismiss,
  });

  final InteractionRecord interaction;
  final String? currentUserImageUrl;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final otherName =
        interaction.fromUserName?.trim().isNotEmpty == true
            ? interaction.fromUserName!.trim()
            : 'Someone';
    final otherImageUrl = interaction.fromUserProfileImageUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEDE8FF), Color(0xFFD8CCFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 20,
                child: GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 60),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: const Color(0xFFB18DFF),
                                  width: 6,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(44),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Not a Match',
                                      style: TextStyle(
                                        fontFamily: TFonts.nunito,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$otherName chose something else.\nyou\'ll never know 😭',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: TFonts.nunito,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF555555),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Positioned(
                              top: 0,
                              child: SizedBox(
                                width: 300,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      left: 45,
                                      child: MatchAvatar(
                                        imageUrl: currentUserImageUrl,
                                        fallbackText: 'Y',
                                        ringColor: const Color(0xFFB18DFF),
                                      ),
                                    ),
                                    Positioned(
                                      right: 45,
                                      child: MatchAvatar(
                                        imageUrl: otherImageUrl,
                                        fallbackText:
                                            otherName.isNotEmpty
                                                ? otherName.characters.first
                                                : 'A',
                                        ringColor: const Color(0xFFB18DFF),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x22000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          '?',
                                          style: TextStyle(
                                            fontFamily: TFonts.nunito,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFB18DFF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            onPressed: onDismiss,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

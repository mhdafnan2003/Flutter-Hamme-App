import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

/// Renders a 1080 × 1920 (9:16) story image for matches.
/// Used as the off-screen RepaintBoundary source before sharing.
class MatchShareExportWidget extends StatelessWidget {
  final InteractionType type;
  final String otherName;
  final String? otherImageUrl;
  final String? myImageUrl;

  const MatchShareExportWidget({
    super.key,
    required this.type,
    required this.otherName,
    this.otherImageUrl,
    this.myImageUrl,
  });

  // ── canvas constants ────────────────────────────────────────────────────
  static const double _canvasW = 1080;
  static const double _canvasH = 1920;

  static _MatchExportTheme _theme(InteractionType type) {
    switch (type) {
      case InteractionType.crush:
        return const _MatchExportTheme(
          gradientStart: Color(0xFFFF2E93),
          gradientEnd: Color(0xFFFF77C0),
          emoji: '😍',
          label: 'Crush',
        );
      case InteractionType.friend:
        return const _MatchExportTheme(
          gradientStart: Color(0xFF0066FF),
          gradientEnd: Color(0xFF22CFFF),
          emoji: '🤝',
          label: 'Friend',
        );
      case InteractionType.frenemy:
      case InteractionType.ameny:
        return const _MatchExportTheme(
          gradientStart: Color(0xFF7B5EA7),
          gradientEnd: Color(0xFFB59FD8),
          emoji: '😈',
          label: 'Frenemy',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(type);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _canvasW,
        height: _canvasH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.gradientEnd, theme.gradientStart],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Main Card ─────────────────────────────────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 860,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Card Body
                      Container(
                        margin: const EdgeInsets.only(top: 130),
                        width: 860,
                        padding: const EdgeInsets.fromLTRB(40, 160, 40, 80),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white, width: 8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "It's a Match!",
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 100,
                                color: Colors.white,
                                letterSpacing: -1.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              '$otherName also chose ${theme.label}.\nYou both want the same thing.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w700,
                                fontSize: 44,
                                color: Colors.white,
                                height: 1.4,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Overlapping Avatars
                      Positioned(
                        top: 0,
                        child: SizedBox(
                          width: 480,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 0,
                                child: _ExportAvatar(imageUrl: otherImageUrl, size: 260),
                              ),
                              Positioned(
                                right: 0,
                                child: _ExportAvatar(imageUrl: myImageUrl, size: 260),
                              ),
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    theme.emoji,
                                    style: const TextStyle(
                                      fontSize: 64,
                                      decoration: TextDecoration.none,
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
                ),
                const SizedBox(height: 120),
              ],
            ),

            // ── Bottom Branding ───────────────────────────────────────────
            Positioned(
              bottom: 140,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'play games & meet people',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w700,
                      fontSize: 44,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchExportTheme {
  const _MatchExportTheme({
    required this.gradientStart,
    required this.gradientEnd,
    required this.emoji,
    required this.label,
  });
  final Color gradientStart;
  final Color gradientEnd;
  final String emoji;
  final String label;
}

class _ExportAvatar extends StatelessWidget {
  const _ExportAvatar({this.imageUrl, this.size = 260});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasValidUrl = imageUrl != null && 
                             imageUrl!.isNotEmpty && 
                             imageUrl!.startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: hasValidUrl
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: Colors.white.withValues(alpha: 0.3),
        child: const Icon(
          CupertinoIcons.person_solid, 
          color: Colors.white, 
          size: 140,
        ),
      );
}

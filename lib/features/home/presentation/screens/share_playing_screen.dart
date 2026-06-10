import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class SharePlayingScreen extends ConsumerStatefulWidget {
  final bool autoShare;
  final String? platform;
  const SharePlayingScreen({super.key, this.autoShare = false, this.platform});

  @override
  ConsumerState<SharePlayingScreen> createState() => _SharePlayingScreenState();

  static const double _storyPixelRatio = 1.0;
  static const Size _storyCanvasSize = Size(1080, 1920);
  static const String _instagramAppId = '';
  static const MethodChannel _storyChannel = MethodChannel('hamme/share_story');

  static Future<void> shareStory(
    BuildContext context,
    WidgetRef ref, {
    String? platform,
  }) async {
    try {
      final draft =
          ref.read(onboardingDraftProvider).value ?? const OnboardingDraft();
      final imageBytes = await _captureStoryFromHiddenOverlay(context, draft);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDirectory = await getTemporaryDirectory();
      final tempPath = '${tempDirectory.path}/hamme_story_$timestamp.png';
      await File(tempPath).writeAsBytes(imageBytes);

      final session = ref.read(authControllerProvider).value;
      final shareCode = session?.user.shareCode;
      final shareLink = AppConstants.buildUserShareLink(shareCode);

      final socialShare = AppinioSocialShare();

      if (platform == 'snapchat') {
        try {
          if (Platform.isAndroid) {
            final isInstalled =
                await _storyChannel.invokeMethod<bool>(
                  'isSnapchatInstalled',
                ) ??
                false;
            if (isInstalled) {
              final launchResult = await _storyChannel.invokeMethod<String>(
                'shareToSnapchatStory',
                {'imagePath': tempPath, 'attributionUrl': shareLink},
              );
              if (launchResult == 'SUCCESS') return;
            }
          }
          // iOS or fallback
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempPath)],
              text: 'What do you think of me? $shareLink',
            ),
          );
          return;
        } catch (e) {
          debugPrint('Snapchat share failed: $e');
        }
      } else {
        // Instagram Logic
        try {
          bool instagramInstalled = false;
          if (Platform.isAndroid) {
            instagramInstalled =
                await _storyChannel.invokeMethod<bool>(
                  'isInstagramInstalled',
                ) ??
                false;
          } else {
            final installedApps = await socialShare.getInstalledApps();
            instagramInstalled = installedApps.entries.any(
              (entry) =>
                  entry.value &&
                  (entry.key.toLowerCase().contains('instagram') ||
                      entry.key == 'com.instagram.android'),
            );
          }

          if (instagramInstalled) {
            if (Platform.isAndroid) {
              final launchResult = await _storyChannel.invokeMethod<String>(
                'shareToInstagramStory',
                {'imagePath': tempPath, 'attributionUrl': shareLink},
              );
              if (launchResult == 'SUCCESS') return;
            } else if (Platform.isIOS) {
              await socialShare.iOS.shareToInstagramStory(
                _instagramAppId,
                backgroundImage: tempPath,
                backgroundTopColor: '#9F6FFF',
                backgroundBottomColor: '#9F6FFF',
                attributionURL: shareLink,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Instagram story share failed: $e');
        }
      }

      // Fallback
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempPath)],
          text: 'What do you think of me? $shareLink',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing story: $e');
    }
  }
}

Future<Uint8List> _captureStoryFromHiddenOverlay(
  BuildContext context,
  OnboardingDraft draft,
) async {
  final boundaryKey = GlobalKey();
  final exportRootKey = GlobalKey();
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (_) => Positioned(
          left: -20000,
          top: 0,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: SharePlayingScreen._storyCanvasSize.width,
              height: SharePlayingScreen._storyCanvasSize.height,
              child: StoryExportWidget(key: exportRootKey, draft: draft),
            ),
          ),
        ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await Future.delayed(const Duration(milliseconds: 500));
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Export boundary not available.');
    }

    final image = await boundary.toImage(
      pixelRatio: SharePlayingScreen._storyPixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to convert exported image to PNG bytes.');
    }
    completer.complete();
    return byteData.buffer.asUint8List();
  } finally {
    if (!completer.isCompleted) {
      completer.complete();
    }
    entry.remove();
  }
}

class _SharePlayingScreenState extends ConsumerState<SharePlayingScreen>
    with WidgetsBindingObserver {
  bool _didEnterBackground = false;
  bool _shareLaunchFinished = false;
  bool _didExitLoader = false;

  @override
  void initState() {
    super.initState();
    // Start sharing automatically. Do not navigate away immediately because
    // it can interrupt share intents on some Android devices.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SharePlayingScreen.shareStory(context, ref);
    });
  }



  @override
  Widget build(BuildContext context) {
    // Show a minimal loader while capturing silently
    return const Scaffold(
      backgroundColor: Color(0xFF9F6FFF),
      body: Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 15),
      ),
    );
  }
}

/// The exact design widget for the Instagram/Snapchat Story (9:16 ratio)
class StoryExportWidget extends StatelessWidget {
  final OnboardingDraft draft;
  const StoryExportWidget({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = draft.profileImageUrl;
    final hasProfileImage =
      profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Container(
      width: 1080,
      height: 1920,
      color: const Color(0xFF9F6FFF), // Solid purple
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 120), // Top Safe Zone
          // Profile Image
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: hasProfileImage
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.person_solid,
                    size: 120,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 40),
          // Question Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'What do you think of me?',
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 42,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Anonymous Text
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🙈',
                style: TextStyle(
                  fontSize: 32,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'send anonymously',
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          // Buttons
          _StoryButton(
            text: 'Friend',
            emoji: '\u{1F91D}',
            colors: [Color(0xFF14D5F5), Color(0xFF0067FF)],
          ),
          const SizedBox(height: 25),
          _StoryButton(
            text: 'Crush',
            emoji: '\u{1F60D}',
            colors: [Color(0xFFD74CDB), Color(0xFFFF3190)],
          ),
          const SizedBox(height: 25),
          _StoryButton(
            text: 'Frenemy',
            emoji: '\u{1F608}',
            colors: [Color(0xFFB6A8EA), Color(0xFF595A96)],
          ),
          const SizedBox(height: 60),
          // Tooltip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              'Tap to play',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 36,
                fontFamily: TFonts.nunito,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(40, 20),
            painter: TrianglePainter(),
          ),
          const SizedBox(height: 10),
          // Link Sticker Area
          CustomPaint(
            painter: DashedRectPainter(
              color: Colors.white70,
              strokeWidth: 4,
              gap: 10,
            ),
            child: Container(
              width: 600,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.link, color: Color(0xFF00C2FF), size: 70),
                    SizedBox(width: 20),
                    Text(
                      'PLACE LINK\nSTICKER HERE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                        fontFamily: TFonts.nunito,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StoryArrow(),
              const SizedBox(width: 100),
              _StoryArrow(),
              const SizedBox(width: 100),
              _StoryArrow(),
            ],
          ),
          const SizedBox(height: 150),
          // Footer
          Image.asset(TImages.hammeLogo, height: 90),
          const SizedBox(height: 10),
          const Text(
            'play games & meet people',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w800,
              fontSize: 32,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 130), // Bottom Safe Zone
        ],
      ),
    );
  }
}

class _StoryButton extends StatelessWidget {
  final String text;
  final String emoji;
  final List<Color> colors;

  const _StoryButton({
    required this.text,
    required this.emoji,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 700,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 42,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 15),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 42,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 110),
      painter: ArrowPainter(strokeWidth: 12),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 4),
    );
    path.addRRect(rrect);

    final dashPath = Path();
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ArrowPainter extends CustomPainter {
  final double strokeWidth;
  ArrowPainter({this.strokeWidth = 5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Vertical line
    path.moveTo(size.width / 2, size.height);
    path.lineTo(size.width / 2, 0);
    
    // Left tip
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width * 0.1, size.height * 0.4);
    
    // Right tip
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width * 0.9, size.height * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

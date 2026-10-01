import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
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
  static const MethodChannel _storyChannel = MethodChannel('hamme/share_story');

  static Future<void> shareStory(
    BuildContext context,
    WidgetRef ref, {
    String? platform,
  }) async {
    try {
      final draft =
          ref.read(onboardingDraftProvider).value ?? const OnboardingDraft();
      final imageBytes = await _captureStoryFromHiddenOverlay(
        context,
        draft,
        // Instagram needs a place for the user-added link sticker; Snapchat's
        // Figma template shows the brand link on the shared image.
        showBrandLink: platform == 'snapchat',
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDirectory = await getTemporaryDirectory();
      final tempPath = '${tempDirectory.path}/hamme_story_$timestamp.png';
      await File(tempPath).writeAsBytes(imageBytes);

      final session = ref.read(authControllerProvider).value;
      final shareCode = session?.user.shareCode;
      final shareLink = AppConstants.buildUserShareLink(shareCode);

      // Auto-copy share link to clipboard so user can paste into link sticker
      await Clipboard.setData(ClipboardData(text: shareLink));

      if (platform == 'snapchat') {
        try {
          if (Platform.isAndroid) {
            final isInstalled =
                await _storyChannel.invokeMethod<bool>('isSnapchatInstalled') ??
                false;
            if (isInstalled) {
              final launchResult = await _storyChannel.invokeMethod<String>(
                'shareToSnapchatStory',
                {'imagePath': tempPath, 'attributionUrl': shareLink},
              );
              if (launchResult == 'SUCCESS') return;
            }
          }
          // iOS has no Snapchat story API without Snap Kit, so use the share
          // sheet. Share the image alone: bundling text makes Snapchat's share
          // extension treat it as a link. The link is already on the clipboard.
          if (!context.mounted) return;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempPath, mimeType: 'image/png')],
              text:
                  Platform.isIOS ? null : 'What do you think of me? $shareLink',
              sharePositionOrigin: _shareOrigin(context),
            ),
          );
          return;
        } catch (e) {
          debugPrint('Snapchat share failed: $e');
        }
      } else {
        // Instagram Logic
        try {
          final instagramInstalled =
              await _storyChannel.invokeMethod<bool>('isInstagramInstalled') ??
              false;
          if (instagramInstalled) {
            final launchResult = await _storyChannel.invokeMethod<String>(
              'shareToInstagramStory',
              {'imagePath': tempPath, 'attributionUrl': shareLink},
            );
            if (launchResult == 'SUCCESS') return;
          }
        } catch (e) {
          debugPrint('Instagram story share failed: $e');
        }
      }

      // Fallback
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempPath, mimeType: 'image/png')],
          text: 'What do you think of me? $shareLink',
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } catch (e) {
      debugPrint('Error sharing story: $e');
    }
  }

  // Required on iPad, where the share sheet is a popover.
  static Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

Future<Uint8List> _captureStoryFromHiddenOverlay(
  BuildContext context,
  OnboardingDraft draft, {
  required bool showBrandLink,
}) async {
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
              child: StoryExportWidget(
                key: exportRootKey,
                draft: draft,
                showBrandLink: showBrandLink,
              ),
            ),
          ),
        ),
  );

  // Download the profile photo first so it is not blank in the capture.
  final profileImageUrl = draft.profileImageUrl;
  if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
    try {
      await precacheImage(
        NetworkImage(profileImageUrl),
        context,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
  if (!context.mounted) throw StateError('Share context is no longer mounted.');

  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await Future.delayed(const Duration(milliseconds: 500));
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
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

class _SharePlayingScreenState extends ConsumerState<SharePlayingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SharePlayingScreen.shareStory(
        context,
        ref,
        platform: widget.platform,
      );
      if (mounted) context.go('/home');
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

/// Figma story artwork fitted uniformly onto an Instagram/Snapchat 9:16 canvas.
class StoryExportWidget extends StatelessWidget {
  final OnboardingDraft draft;
  final bool showBrandLink;
  const StoryExportWidget({
    super.key,
    required this.draft,
    this.showBrandLink = false,
  });

  // Keep Figma's 360x800 composition uniformly scaled on the 9:16 canvas.
  static const double _avatarSize = 300;
  static const double _contentWidth = 840;

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = draft.profileImageUrl;
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;

    const avatarFallback = ColoredBox(
      color: Color(0xFFB99BFF),
      child: Center(
        child: Icon(
          CupertinoIcons.person_solid,
          size: 130,
          color: Colors.white,
        ),
      ),
    );

    // The story is captured in an overlay with no Material ancestor, so give
    // it a text style; otherwise Flutter's yellow debug underline shows.
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Container(
        width: 1080,
        height: 1920,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9E6EFE), Color(0xFF7737FD)],
          ),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1080,
            height: 2400,
            child: Column(
              children: [
                const SizedBox(height: 303),
                // The card covers the bottom of the avatar's white ring, so the
                // two white shapes join into one.
                SizedBox(
                  width: _contentWidth,
                  height: _avatarSize + 108 - 15,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Shadows first, so neither white shape casts onto the other
                      // and the ring and card read as one joined shape.
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 108,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        padding: const EdgeInsets.all(15),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child:
                              hasProfileImage
                                  ? Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => avatarFallback,
                                  )
                                  : avatarFallback,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 108,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Text(
                            'What do you think of me?',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w800,
                              fontSize: 54,
                              height: 25 / 18,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Anonymous Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(TImages.emojiMonkey, width: 48, height: 48),
                    const SizedBox(width: 12),
                    Text(
                      'send anonymously',
                      style: TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w600,
                        fontSize: 42,
                        height: 19 / 14,
                        color: const Color(0xFFEAE7E7),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Buttons
                const _StoryButton(
                  text: 'Friend',
                  emojiPath: TImages.emojiFriend,
                  colors: [Color(0xFF00CCFE), Color(0xFF005EFB)],
                ),
                const SizedBox(height: 24),
                const _StoryButton(
                  text: 'Crush',
                  emojiPath: TImages.emojiCrush,
                  colors: [Color(0xFFCE58E6), Color(0xFFFE3B9D)],
                ),
                const SizedBox(height: 24),
                const _StoryButton(
                  text: 'Frenemy',
                  emojiPath: TImages.emojiFrenemy,
                  colors: [Color(0xFFBBADED), Color(0xFF50528D)],
                ),
                const SizedBox(height: 96),
                SizedBox(
                  width: 480,
                  height: 493,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/placelink.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      if (showBrandLink)
                        Positioned(
                        left: 24,
                          top: 150,
                          child: Container(
                            width: 435,
                            height: 144,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(27),
                            ),
                            child: Padding(
                            padding: const EdgeInsets.only(left: 96),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 66,
                                    height: 72,
                                    child: Center(
                                      child: Transform.scale(
                                        scale: 3,
                                        child: SvgPicture.asset(
                                          'assets/images/story_link_icon.svg',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  SizedBox(
                                    width: 225,
                                    child: FittedBox(
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.scaleDown,
                                      child: const Text(
                                        'HAMME.LINK',
                                        style: TextStyle(
                                          fontFamily: TFonts.nunito,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 36,
                                          height: 1,
                                          color: Colors.black,
                                          decoration: TextDecoration.none,
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
                const SizedBox(height: 74),
                // Footer
                SizedBox(
                  width: 264,
                  height: 99,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Hamme',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontSize: 72,
                          fontWeight: FontWeight.w800,
                          height: 33 / 24,
                          foreground:
                              Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 12
                                ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'Hamme',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontSize: 72,
                          fontWeight: FontWeight.w800,
                          height: 33 / 24,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'play games  &  meet people',
                  style: TextStyle(
                    fontFamily: TFonts.schibstedGrotesk,
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    height: 15 / 12,
                    letterSpacing: -2.16,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryButton extends StatelessWidget {
  final String text;
  final String emojiPath;
  final List<Color> colors;

  const _StoryButton({
    required this.text,
    required this.emojiPath,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 780,
      height: 144,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(54),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(emojiPath, width: 66, height: 66),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w800,
              fontSize: 54,
              height: 25 / 18,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

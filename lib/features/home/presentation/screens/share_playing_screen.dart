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
import 'package:hamme_app/core/widgets/emoji_image.dart';
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
  // The Meta App ID is required by Instagram's Story-sharing handoff.
  // Supply it at build time with --dart-define=META_APP_ID=<your-app-id>.
  static const String _instagramAppId = String.fromEnvironment('META_APP_ID');
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

      // Auto-copy share link to clipboard so user can paste into link sticker
      await Clipboard.setData(ClipboardData(text: shareLink));

      final socialShare = AppinioSocialShare();

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
        if (Platform.isIOS &&
            (_instagramAppId.isEmpty ||
                int.tryParse(_instagramAppId) == null)) {
          debugPrint(
            'Instagram Stories is disabled: META_APP_ID is missing or invalid.',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Instagram Stories is temporarily unavailable.'),
              ),
            );
          }
          return;
        }
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

/// The exact design widget for the Instagram/Snapchat Story (9:16 ratio)
class StoryExportWidget extends StatelessWidget {
  final OnboardingDraft draft;
  const StoryExportWidget({super.key, required this.draft});

  static const double _avatarSize = 270;
  static const double _contentWidth = 750;

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
            colors: [Color(0xFFA47CFF), Color(0xFF7B3FF2)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            // The card covers the bottom of the avatar's white ring, so the
            // two white shapes join into one.
            SizedBox(
              width: _contentWidth,
              height: _avatarSize + 96 - 12,
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
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    padding: const EdgeInsets.all(12),
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
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'What do you think of me?',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 48,
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
                const EmojiImage(emoji: '\u{1F648}', size: 34),
                const SizedBox(width: 10),
                Text(
                  'send anonymously',
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    color: Colors.white.withValues(alpha: 0.85),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Buttons
            const _StoryButton(
              text: 'Friend',
              emoji: '\u{1F91D}',
              colors: [Color(0xFF14D5F5), Color(0xFF3A63FF)],
            ),
            const SizedBox(height: 24),
            const _StoryButton(
              text: 'Crush',
              emoji: '\u{1F60D}',
              colors: [Color(0xFFD74CDB), Color(0xFFFF3190)],
            ),
            const SizedBox(height: 24),
            const _StoryButton(
              text: 'Frenemy',
              emoji: '\u{1F608}',
              colors: [Color(0xFFB6A8EA), Color(0xFF595A96)],
            ),
            const SizedBox(height: 80),
            Image.asset(
              'assets/images/placelink.png',
              width: 410,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 70),
            // Footer
            Image.asset(TImages.hammeLogo, height: 95),
            const SizedBox(height: 10),
            Text(
              'play games & meet people',
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 30,
                color: Colors.white.withValues(alpha: 0.85),
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
          ],
        ),
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
      height: 128,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmojiImage(emoji: emoji, size: 46),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 46,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

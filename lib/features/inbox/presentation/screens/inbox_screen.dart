import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/inbox_share_export_widget.dart';
import '../widgets/inbox_reaction_card.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isInstagramSelected = true;
  bool _isSharing = false;

  static const String _instagramAppId = ''; // Replace if you have a specific Meta App ID
  static const MethodChannel _storyChannel = MethodChannel('hamme/share_story');

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final variation = _variations[_currentPage];
      final interactions = ref.read(receivedInteractionsProvider).value ?? [];
      final count = _countByType(
        {for (var i in interactions) i.type.name: interactions.where((it) => it.type == i.type).length},
        variation.typeKey,
      );
      
      final draft = ref.read(onboardingDraftProvider).value ?? const OnboardingDraft();
      final profileImageUrl = draft.profileImageUrl;

      // 1. Capture the image silently
      final imageBytes = await _captureStoryFromHiddenOverlay(
        context,
        variation,
        count,
        profileImageUrl,
        _isInstagramSelected,
      );

      // 2. Save to temp file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDirectory = await getTemporaryDirectory();
      final tempPath = '${tempDirectory.path}/hamme_inbox_share_$timestamp.png';
      await File(tempPath).writeAsBytes(imageBytes);

      // 3. Prepare share link
      final session = ref.read(authControllerProvider).value;
      final shareCode = session?.user.shareCode;
      final shareLink = AppConstants.buildUserShareLink(shareCode);

      // 4. Share to platform
      final socialShare = AppinioSocialShare();

      if (!_isInstagramSelected) {
        // Snapchat Logic
        try {
          if (Platform.isAndroid) {
            final isInstalled = await _storyChannel.invokeMethod<bool>('isSnapchatInstalled') ?? false;
            if (isInstalled) {
              await _storyChannel.invokeMethod('shareToSnapchatStory', {
                'imagePath': tempPath,
                'attributionUrl': shareLink,
              });
              return;
            }
          }
          // iOS or fallback
          await Share.shareXFiles([XFile(tempPath)], text: 'Check out my reactions on Hamme! $shareLink');
        } catch (e) {
          debugPrint('Snapchat share failed: $e');
        }
      } else {
        // Instagram Logic
        try {
          bool instagramInstalled = false;
          if (Platform.isAndroid) {
            instagramInstalled = await _storyChannel.invokeMethod<bool>('isInstagramInstalled') ?? false;
          } else {
            final installedApps = await socialShare.getInstalledApps();
            instagramInstalled = installedApps.entries.any(
              (entry) => entry.value && entry.key.toLowerCase().contains('instagram'),
            );
          }

          if (instagramInstalled) {
            if (Platform.isAndroid) {
              await _storyChannel.invokeMethod('shareToInstagramStory', {
                'imagePath': tempPath,
                'attributionUrl': shareLink,
              });
              return;
            } else if (Platform.isIOS) {
              await socialShare.iOS.shareToInstagramStory(
                _instagramAppId,
                backgroundImage: tempPath,
                attributionURL: shareLink,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Instagram share failed: $e');
        }
      }

      // Final Fallback
      await Share.shareXFiles([XFile(tempPath)], text: 'Check out my reactions on Hamme! $shareLink');

    } catch (e) {
      debugPrint('Error in _captureAndShare: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<Uint8List> _captureStoryFromHiddenOverlay(
    BuildContext context,
    InboxVariation variation,
    int count,
    String? profileImageUrl,
    bool isInstagram,
  ) async {
    final boundaryKey = GlobalKey();
    final completer = Completer<void>();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -20000,
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 1080,
            height: 1920,
            child: InboxShareExportWidget(
              variation: variation,
              count: count,
              profileImageUrl: profileImageUrl,
              isInstagram: isInstagram,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      await Future.delayed(const Duration(milliseconds: 600)); // Allow time for fonts/images to render
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Boundary not available');

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Failed to convert to PNG');

      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  final List<InboxVariation> _variations = const [
    InboxVariation(
      gradientColors: [TColors.hammeInboxPinkStart, TColors.hammeInboxPinkEnd],
      borderColor: TColors.hammeInboxPinkBorder,
      emoji: '😍',
      typeKey: 'crush',
      tagline: 'Main character energy',
    ),
    InboxVariation(
      gradientColors: [TColors.hammeInboxBlueStart, TColors.hammeInboxBlueEnd],
      borderColor: TColors.hammeInboxBlueBorder,
      emoji: '🤝',
      typeKey: 'friend',
      tagline: 'Squad goals fr',
    ),
    InboxVariation(
      gradientColors: [
        TColors.hammeInboxPurpleStart,
        TColors.hammeInboxPurpleEnd,
      ],
      borderColor: TColors.hammeInboxPurpleBorder,
      emoji: '😈',
      typeKey: 'frenemy',
      tagline: 'Too many haters',
    ),
  ];

  int _countByType(Map<String, int> counts, String key) {
    if (key == 'frenemy') {
      return (counts['frenemy'] ?? 0) + (counts['ameny'] ?? 0);
    }
    return counts[key] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(receivedInteractionsProvider);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingPlay = ref.watch(pendingPlayInteractionsProvider);
    final playCount = pendingPlay.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const HammeTopBar(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Carousel
                  SizedBox(
                    height: 320, // Reduced to bring indicators closer
                    child: Builder(
                      builder: (context) {
                        final interactions = ref.watch(receivedInteractionsProvider);
                        final draftAsync = ref.watch(onboardingDraftProvider);
                        final profileImageUrl = draftAsync.maybeWhen(
                          data: (d) => d.profileImageUrl,
                          orElse: () => null,
                        );

                        return interactions.when(
                          data: (items) {
                            final counts = <String, int>{};
                            for (final item in items) {
                              final key = item.type.name;
                              counts[key] = (counts[key] ?? 0) + 1;
                            }
                            return PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) => setState(() => _currentPage = index),
                              itemCount: _variations.length,
                              itemBuilder: (context, index) {
                                final variation = _variations[index];
                                final count = _countByType(counts, variation.typeKey);
                                return InboxReactionCard(
                                  variation: variation,
                                  count: count,
                                  imageUrl: profileImageUrl,
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const Center(child: Text('Error loading reactions')),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 2), // Move indicators just below the card

                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _variations.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _variations[_currentPage].borderColor
                              : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Social Platform Toggle (High Fidelity) ─────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _isInstagramSelected = !_isInstagramSelected),
                    child: Container(
                      width: 110,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF444444), // Dark grey base
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          // Sliding Indicator Circle
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: _isInstagramSelected
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              width: 55, // Half of 110
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9A9A9A), // Lighter grey indicator
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                          // Icons Row
                          Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Image.asset(
                                    TImages.instaOutline,
                                    width: 24,
                                    height: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Image.asset(
                                    TImages.snapFill,
                                    width: 24,
                                    height: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Share Button ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isSharing ? null : _captureAndShare,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isSharing
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    _isInstagramSelected
                                        ? TImages.instaOutline
                                        : TImages.snapFill,
                                    width: 30,
                                    height: 30,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Share',
                                    style: TextStyle(
                                      fontFamily: TFonts.nunito,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      color: Colors.white,
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
          ],
        ),
      ),
      bottomNavigationBar: HammeBottomNavBar(
        currentIndex: 2,
        playBadgeCount: playCount,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/play');
          }
        },
      ),
    );
  }
}

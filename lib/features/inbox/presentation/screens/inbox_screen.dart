import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/features/safety/domain/models/safety_target.dart';
import 'package:hamme_app/features/safety/presentation/widgets/safety_actions.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/inbox_share_export_widget.dart';
import '../widgets/inbox_reaction_card.dart';
import '../widgets/inbox_votes_section.dart';
import 'package:hamme_app/utils/popups/app_snack_bar.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.94);
  int _currentPage = 0;
  bool _isInstagramSelected = true;
  bool _isSharing = false;
  static const MethodChannel _storyChannel = MethodChannel('hamme/share_story');

  // Required on iPad, where the share sheet is a popover.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final variation = _variations[_currentPage];
      final interactions =
          ref.read(visibleInboxInteractionsProvider).valueOrNull ?? [];
      final count = _countByType({
        for (var i in interactions)
          i.type.name: interactions.where((it) => it.type == i.type).length,
      }, variation.typeKey);

      final draft =
          ref.read(onboardingDraftProvider).value ?? const OnboardingDraft();
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

      // Auto-copy share link to clipboard so user can paste into link sticker
      await Clipboard.setData(ClipboardData(text: shareLink));

      // 4. Share to platform
      if (!_isInstagramSelected) {
        // Snapchat Logic — share to Snapchat Story
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
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempPath, mimeType: 'image/png')],
              text:
                  Platform.isIOS
                      ? null
                      : 'Check out my reactions on Hamme! $shareLink',
              sharePositionOrigin: _shareOrigin(),
            ),
          );
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
          debugPrint('Instagram share failed: $e');
        }
      }

      // Final Fallback
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempPath, mimeType: 'image/png')],
          text: 'Check out my reactions on Hamme! $shareLink',
          sharePositionOrigin: _shareOrigin(),
        ),
      );
    } catch (e) {
      debugPrint('Error in _captureAndShare: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          'Failed to share. Please try again.',
          type: AppSnackBarType.error,
        );
      }
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
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (_) => Positioned(
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
      await Future.delayed(
        const Duration(milliseconds: 600),
      ); // Allow time for fonts/images to render
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleInteractions = ref.watch(visibleInboxInteractionsProvider);
    final selectedType = _variations[_currentPage].typeKey;
    final hasReactions =
        visibleInteractions.valueOrNull?.any((item) {
          final type = item.type.name;
          return type == selectedType ||
              (selectedType == 'frenemy' && type == 'ameny');
        }) ??
        false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const HammeTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final topGap =
                      hasReactions
                          ? (constraints.maxHeight - 467).clamp(20.0, 59.0)
                          : 87.0;
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: topGap),

                        // Carousel
                        SizedBox(
                          height: 283,
                          child: Builder(
                            builder: (context) {
                              // Hidden, reported and blocked votes don't count.
                              final interactions = ref.watch(
                                visibleInboxInteractionsProvider,
                              );
                              final draftAsync = ref.watch(
                                onboardingDraftProvider,
                              );
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
                                  return Stack(
                                    children: [
                                      PageView.builder(
                                        controller: _pageController,
                                        onPageChanged:
                                            (index) => setState(
                                              () => _currentPage = index,
                                            ),
                                        itemCount: _variations.length,
                                        itemBuilder: (context, index) {
                                          final variation = _variations[index];
                                          final count = _countByType(
                                            counts,
                                            variation.typeKey,
                                          );
                                          return InboxReactionCard(
                                            variation: variation,
                                            count: count,
                                            imageUrl: profileImageUrl,
                                          );
                                        },
                                      ),
                                      if (!hasReactions) ...[
                                        const Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: 8,
                                          child: IgnorePointer(
                                            child: ColoredBox(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const Positioned(
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: 8,
                                          child: IgnorePointer(
                                            child: ColoredBox(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                                loading:
                                    () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                error:
                                    (_, __) => const Center(
                                      child: Text('Error loading reactions'),
                                    ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Page Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _variations.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPage == index ? 16 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _currentPage == index
                                        ? _variations[_currentPage].borderColor
                                        : const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 44),

                        // ── Social Platform Toggle & Share Button ──────────────────
                        // Only show when current page has count > 0
                        Builder(
                          builder: (context) {
                            final interactions = ref.watch(
                              visibleInboxInteractionsProvider,
                            );
                            final currentCount = interactions.maybeWhen(
                              data: (items) {
                                final counts = <String, int>{};
                                for (final item in items) {
                                  final key = item.type.name;
                                  counts[key] = (counts[key] ?? 0) + 1;
                                }
                                return _countByType(
                                  counts,
                                  _variations[_currentPage].typeKey,
                                );
                              },
                              orElse: () => 0,
                            );

                            if (currentCount == 0) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              children: [
                                // ── Social Platform Toggle (High Fidelity) ─────────────────────
                                GestureDetector(
                                  onTap:
                                      () => setState(
                                        () =>
                                            _isInstagramSelected =
                                                !_isInstagramSelected,
                                      ),
                                  child: Container(
                                    width: 84,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF666666),
                                      borderRadius: BorderRadius.circular(19),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Sliding Indicator Circle
                                        AnimatedAlign(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                          alignment:
                                              _isInstagramSelected
                                                  ? Alignment.centerLeft
                                                  : Alignment.centerRight,
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF9A9A9A,
                                              ), // Lighter grey indicator
                                              borderRadius:
                                                  BorderRadius.circular(19),
                                            ),
                                          ),
                                        ),
                                        // Icons Row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 9,
                                              ),
                                              child: Image.asset(
                                                TImages.instaOutline,
                                                width: 20,
                                                height: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 9,
                                              ),
                                              child: Image.asset(
                                                TImages.snapFill,
                                                width: 20,
                                                height: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ── Share Button ───────────────────────────────────────
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 62,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isSharing ? null : _captureAndShare,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child:
                                          _isSharing
                                              ? const CupertinoActivityIndicator(
                                                color: Colors.white,
                                              )
                                              : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Image.asset(
                                                    _isInstagramSelected
                                                        ? TImages.instaOutline
                                                        : TImages.snapFill,
                                                    width: 25,
                                                    height: 25,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  const Text(
                                                    'Share',
                                                    style: TextStyle(
                                                      fontFamily: TFonts.nunito,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        // ── Received votes: hide / report / block ─────────────
                        Builder(
                          builder: (_) {
                            final votes =
                                ref
                                    .watch(visibleInboxInteractionsProvider)
                                    .valueOrNull ??
                                const [];
                            final manageable =
                                votes.where(isInboxManageableVote).toList();
                            if (manageable.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 40,
                                bottom: 32,
                              ),
                              child: InboxVotesSection(
                                votes: manageable,
                                waitingInPlayCount:
                                    votes.length - manageable.length,
                                // The screen's context, which outlives the row.
                                onSafetyActions:
                                    (vote) => showSafetyActions(
                                      context,
                                      SafetyTarget.vote(vote),
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/providers/play_limit_provider.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/play_empty_state.dart';
import '../widgets/match_share_export_widget.dart';
import '../widgets/match_success_overlay.dart';
import '../widgets/play_cooldown_view.dart';
import '../widgets/poll_match_overlay.dart';
import '../widgets/poll_not_a_match_overlay.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  InteractionResult? _lastResult;
  InteractionRecord? _rewoundItem;
  InteractionRecord? _lastVotedItem;

  // Tracks which match IDs have already been shown as overlays this session
  // so we don't re-show them on every 5-second refresh.
  final Set<String> _shownMatchIds = {};
  // Tracks interaction IDs already shown as poller-side "not a match" overlays.
  final Set<String> _shownPollerResultIds = {};

  void _refreshPlayData() {
    ref.invalidate(receivedInteractionsProvider);
    ref.invalidate(pendingPlayInteractionsProvider);
    ref.invalidate(playLimitStatusProvider);
  }

  void _onDismiss() {
    setState(() {
      _lastResult = null;
    });
  }

  void _triggerRewind() {
    if (_lastVotedItem == null) return;
    setState(() {
      _rewoundItem = _lastVotedItem;
      _lastResult = null;
    });
  }

  /// Called whenever matchesProvider refreshes — shows overlays for any
  /// recent matches not yet seen this session (covers the poller side).
  void _checkForNewMatchesFromPollerSide(List<MatchRecord> matches) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    for (final match in matches) {
      if (_shownMatchIds.contains(match.id)) continue;
      // Skip matches older than 24 h — user can see them in the Matches tab.
      if (match.createdAt.toUtc().isBefore(cutoff)) {
        _shownMatchIds.add(match.id);
        continue;
      }
      _shownMatchIds.add(match.id);
      // Defer to avoid triggering navigation during a build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPollMatchOverlay(match);
      });
    }
  }

  Future<void> _showPollMatchOverlay(MatchRecord match) async {
    final myImageUrl = ref.read(onboardingDraftProvider).value?.profileImageUrl;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, _, __) => PollMatchOverlay(
          match: match,
          currentUserImageUrl: myImageUrl,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// Called when receivedInteractionsProvider refreshes — shows a "not a match"
  /// overlay for the poller (the person who voted via share link) when the
  /// creator voted back but it wasn't a match.
  void _checkForNotMatchFromPollerSide(List<InteractionRecord> interactions) {
    for (final interaction in interactions) {
      if (_shownPollerResultIds.contains(interaction.id)) continue;

      // We only care about cards where:
      // – the current user already voted for the other person (respondedByCurrentUser)
      // – the other person voted back (fromUser is known)
      // – it is NOT a match (matched: true is handled by matchesProvider)
      if (!interaction.respondedByCurrentUser ||
          interaction.matched ||
          interaction.fromUser == null ||
          interaction.fromUser!.isEmpty) {
        _shownPollerResultIds.add(interaction.id);
        continue;
      }

      // Only surface results from the last 24 h — older ones stay in the Matches tab.
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      if (interaction.createdAt.toUtc().isBefore(cutoff)) {
        _shownPollerResultIds.add(interaction.id);
        continue;
      }

      _shownPollerResultIds.add(interaction.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPollNotAMatchOverlay(interaction);
      });
    }
  }

  Future<void> _showPollNotAMatchOverlay(InteractionRecord interaction) async {
    final myImageUrl = ref.read(onboardingDraftProvider).value?.profileImageUrl;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, _, __) => PollNotAMatchOverlay(
          interaction: interaction,
          currentUserImageUrl: myImageUrl,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// Shows the full-screen match celebration on the root navigator so it
  /// covers the persistent bottom navigation bar.
  Future<void> _showMatchOverlay(InteractionResult result) async {
    // Mark as seen so the matchesProvider listener doesn't re-show it.
    if (result.match?.id != null) {
      _shownMatchIds.add(result.match!.id);
    }
    final myImageUrl = ref.read(onboardingDraftProvider).value?.profileImageUrl;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (overlayContext, _, __) => MatchSuccessOverlay(
          result: result,
          currentUserImageUrl: myImageUrl,
          onDismiss: () => Navigator.of(overlayContext).pop(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPlayData();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _refreshPlayData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPlayData();
      unawaited(ref.read(authControllerProvider.notifier).refreshUser());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingPlayInteractionsProvider);
    final controller = ref.watch(interactionControllerProvider);
    final limitStatus = ref.watch(playLimitStatusProvider);

    // Listen for new matches that the poller should see (arrived from the other side).
    ref.listen<AsyncValue<List<MatchRecord>>>(matchesProvider, (_, next) {
      next.whenData(_checkForNewMatchesFromPollerSide);
    });

    // Listen for "not a match" results the poller should see when the creator
    // voted back but it wasn't a match.
    ref.listen<AsyncValue<List<InteractionRecord>>>(receivedInteractionsProvider, (_, next) {
      next.whenData(_checkForNotMatchFromPollerSide);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            const HammeTopBar(),
            Expanded(
              child: limitStatus.when(
                data: (status) {
                  // Show cooldown wall for free users who hit the limit
                  if (status.limited) {
                    return SingleChildScrollView(
                      child: PlayCooldownView(
                        status: status,
                        onCooldownEnd: _refreshPlayData,
                      ),
                    );
                  }

                  return _lastResult != null && !_lastResult!.matched
                      ? _NotAMatchView(
                          result: _lastResult!,
                          remainingCount: (pending.value?.length ?? 0),
                          onSeeNext: _onDismiss,
                          onRewind: _triggerRewind,
                        )
                      : pending.when(
                          data: (items) {
                            final effectiveItem = _rewoundItem ?? (items.isEmpty ? null : items.first);
                            if (effectiveItem == null) return const _CompletedQueueView();
                            return _PlayQueue(
                              item: effectiveItem,
                              remainingCount: items.length,
                              isSubmitting: controller.isLoading,
                              onSelect: (type) async {
                                final targetUserId = effectiveItem.fromUser;
                                if (targetUserId == null || targetUserId.isEmpty) return;
                                _lastVotedItem = effectiveItem;
                                setState(() => _rewoundItem = null);
                                try {
                                  final result = await ref
                                      .read(interactionControllerProvider.notifier)
                                      .respondToUser(
                                        targetUserId: targetUserId,
                                        type: type,
                                      );
                                  if (!mounted) return;
                                  // Refresh limit status after each vote
                                  ref.invalidate(playLimitStatusProvider);

                                  final mergedResult = result.copyWith(
                                    interaction: result.interaction.copyWith(
                                      fromUserName: result.interaction.fromUserName ?? effectiveItem.fromUserName,
                                      fromUserUsername: result.interaction.fromUserUsername ?? effectiveItem.fromUserUsername,
                                      fromUserProfileImageUrl: result.interaction.fromUserProfileImageUrl ?? effectiveItem.fromUserProfileImageUrl,
                                      fromUserInstagramId: result.interaction.fromUserInstagramId ?? effectiveItem.fromUserInstagramId,
                                      fromUserSnapchatId: result.interaction.fromUserSnapchatId ?? effectiveItem.fromUserSnapchatId,
                                    ),
                                  );

                                  if (mergedResult.matched) {
                                    await _showMatchOverlay(mergedResult);
                                    if (!mounted) return;
                                    _refreshPlayData();
                                  } else {
                                    setState(() => _lastResult = mergedResult);
                                  }
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Could not save response: $error'),
                                      backgroundColor: TColors.error,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(color: TColors.hammePrimary),
                          ),
                          error: (error, _) => Center(
                            child: Text(
                              'Could not load voters.\n$error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: TColors.hammePrimary),
                ),
                error: (_, __) => _lastResult != null && !_lastResult!.matched
                    ? _NotAMatchView(
                        result: _lastResult!,
                        remainingCount: (pending.value?.length ?? 0),
                        onSeeNext: _onDismiss,
                        onRewind: _triggerRewind,
                      )
                    : pending.when(
                        data: (items) {
                          final effectiveItem = _rewoundItem ?? (items.isEmpty ? null : items.first);
                          if (effectiveItem == null) return const _CompletedQueueView();
                          return _PlayQueue(
                            item: effectiveItem,
                            remainingCount: items.length,
                            isSubmitting: controller.isLoading,
                            onSelect: (type) async {
                              final targetUserId = effectiveItem.fromUser;
                              if (targetUserId == null || targetUserId.isEmpty) return;
                              _lastVotedItem = effectiveItem;
                              setState(() => _rewoundItem = null);
                              try {
                                final result = await ref
                                    .read(interactionControllerProvider.notifier)
                                    .respondToUser(
                                      targetUserId: targetUserId,
                                      type: type,
                                    );
                                if (!mounted) return;
                                final mergedResult = result.copyWith(
                                  interaction: result.interaction.copyWith(
                                    fromUserName: result.interaction.fromUserName ?? effectiveItem.fromUserName,
                                    fromUserUsername: result.interaction.fromUserUsername ?? effectiveItem.fromUserUsername,
                                    fromUserProfileImageUrl: result.interaction.fromUserProfileImageUrl ?? effectiveItem.fromUserProfileImageUrl,
                                    fromUserInstagramId: result.interaction.fromUserInstagramId ?? effectiveItem.fromUserInstagramId,
                                    fromUserSnapchatId: result.interaction.fromUserSnapchatId ?? effectiveItem.fromUserSnapchatId,
                                  ),
                                );
                                if (mergedResult.matched) {
                                  await _showMatchOverlay(mergedResult);
                                  if (!mounted) return;
                                  _refreshPlayData();
                                } else {
                                  setState(() => _lastResult = mergedResult);
                                }
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not save response: $error'),
                                    backgroundColor: TColors.error,
                                  ),
                                );
                              }
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: TColors.hammePrimary),
                        ),
                        error: (error, _) => Center(
                          child: Text(
                            'Could not load voters.\n$error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// It's a Match! View — full-screen overlay
// ─────────────────────────────────────────────────────────────────────────────

class _MatchView extends ConsumerStatefulWidget {
  const _MatchView({
    required this.result,
    required this.onDismiss,
  });

  final InteractionResult result;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends ConsumerState<_MatchView> {
  String? _selectedPlatform;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // Default platform priority: Instagram > Snapchat
    final interaction = widget.result.interaction;
    final otherInstagram = widget.result.match?.matchedUser.instagramId ?? '';
    final otherSnap = interaction.fromUserSnapchatId ?? '';

    if (otherInstagram.isNotEmpty) {
      _selectedPlatform = 'instagram';
    } else if (otherSnap.isNotEmpty) {
      _selectedPlatform = 'snapchat';
    }
  }

  Future<Uint8List> _renderImage({
    required InteractionType type,
    required String otherName,
    String? otherImageUrl,
    String? myImageUrl,
  }) async {
    final boundaryKey = GlobalKey();
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
            child: MatchShareExportWidget(
              type: type,
              otherName: otherName,
              otherImageUrl: otherImageUrl,
              myImageUrl: myImageUrl,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      // Small delay to ensure everything (especially network images) is rendered
      await Future.delayed(const Duration(milliseconds: 800));
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

  Future<void> _shareMatch() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final interaction = widget.result.interaction;
      final match = widget.result.match;
      
      final otherName = match?.matchedUser.name.trim()
          ?? interaction.fromUserName?.trim()
          ?? 'Someone';
      final otherImageUrl = match?.matchedUser.avatarUrl
          ?? interaction.fromUserProfileImageUrl;
      final myImageUrl = ref.read(onboardingDraftProvider).value?.profileImageUrl;

      final bytes = await _renderImage(
        type: interaction.type,
        otherName: otherName,
        otherImageUrl: otherImageUrl,
        myImageUrl: myImageUrl,
      );

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/hamme_match_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(bytes);

      final text = interaction.type == InteractionType.crush
          ? "It's a crush match! 😍"
          : interaction.type == InteractionType.friend
              ? "We matched as friends! 🤝"
              : "Frenemy vibes only 😈";

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  static _MatchTheme themeForType(InteractionType type) {
    switch (type) {
      case InteractionType.crush:
        return const _MatchTheme(
          gradientStart: Color(0xFFFF2E93),
          gradientEnd: Color(0xFFFF77C0),
          emoji: '😍',
          label: 'Crush',
        );
      case InteractionType.friend:
        return const _MatchTheme(
          gradientStart: Color(0xFF0066FF),
          gradientEnd: Color(0xFF22CFFF),
          emoji: '🤝',
          label: 'Friend',
        );
      case InteractionType.frenemy:
        return const _MatchTheme(
          gradientStart: Color(0xFF7B5EA7),
          gradientEnd: Color(0xFFB59FD8),
          emoji: '😈',
          label: 'Frenemy',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.result.interaction;
    final match = widget.result.match;
    final type = interaction.type;
    final theme = themeForType(type);

    // Other person details — from match record or interaction
    final otherName = match?.matchedUser.name.trim()
        ?? interaction.fromUserName?.trim()
        ?? interaction.fromUserUsername?.trim()
        ?? 'Someone';
    final otherImageUrl = match?.matchedUser.avatarUrl
        ?? interaction.fromUserProfileImageUrl;
    final otherInstagram = match?.matchedUser.instagramId ?? '';
    final otherSnap = interaction.fromUserSnapchatId ?? '';

    // My details
    final draftValue = ref.watch(onboardingDraftProvider);
    final myImageUrl = draftValue.value?.profileImageUrl;

    // Determine which social platform to show in the Reply button
    final hasOtherInstagram = otherInstagram.isNotEmpty;
    final hasOtherSnap = otherSnap.isNotEmpty;
    
    // Toggle logic
    final isInstagramSelected = _selectedPlatform == 'instagram';
    final isSnapchatSelected = _selectedPlatform == 'snapchat';

    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.gradientEnd, theme.gradientStart],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Close button ────────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 20),
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ── Main Card ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Overlapping avatars sit above the card
                    SizedBox(
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Left avatar (other person) — offset left
                          Positioned(
                            left: screenSize.width * 0.5 - 32 - 90,
                            child: _MatchAvatar(imageUrl: otherImageUrl, size: 90),
                          ),
                          // Right avatar (me) — offset right
                          Positioned(
                            right: screenSize.width * 0.5 - 32 - 90,
                            child: _MatchAvatar(imageUrl: myImageUrl, size: 90),
                          ),
                          // Centre emoji badge
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: EmojiImage(
                                emoji: theme.emoji,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card body
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "It's a Match!",
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$otherName also chose ${theme.label}.\nYou both want the same thing.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Social platform toggle ───────────────────────────────────
              if (hasOtherInstagram || hasOtherSnap)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasOtherInstagram)
                          GestureDetector(
                            onTap: () => setState(() => _selectedPlatform = 'instagram'),
                            child: _SocialPill(
                              icon: TImages.instagramIcon,
                              selected: isInstagramSelected,
                            ),
                          ),
                        if (hasOtherInstagram && hasOtherSnap)
                          const SizedBox(width: 4),
                        if (hasOtherSnap)
                          GestureDetector(
                            onTap: () => setState(() => _selectedPlatform = 'snapchat'),
                            child: _SocialPill(
                              icon: TImages.snapchatIcon,
                              selected: isSnapchatSelected,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // ── Reply button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: _isSharing
                      ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(36),
                            ),
                            elevation: 0,
                          ),
                          icon: Image.asset(
                            isSnapchatSelected ? TImages.snapchatIcon : TImages.instagramIcon,
                            width: 24,
                            height: 24,
                            errorBuilder: (_, __, ___) => Icon(
                              isSnapchatSelected ? CupertinoIcons.chat_bubble_fill : CupertinoIcons.camera_fill,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          label: const Text(
                            'Reply',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _shareMatch,
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchTheme {
  const _MatchTheme({
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

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({this.imageUrl, this.size = 90});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        imageUrl!.startsWith('http');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.white.withValues(alpha: 0.3),
                    child: const Center(
                      child: CupertinoActivityIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: Colors.white.withValues(alpha: 0.25),
        child: const Icon(CupertinoIcons.person_solid, color: Colors.white, size: 40),
      );
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({required this.icon, required this.selected});
  final String icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.35) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        icon,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not a Match View
// ─────────────────────────────────────────────────────────────────────────────

class _NotAMatchView extends ConsumerStatefulWidget {
  const _NotAMatchView({
    required this.result,
    required this.remainingCount,
    required this.onSeeNext,
    required this.onRewind,
  });

  final InteractionResult result;
  final int remainingCount;
  final VoidCallback onSeeNext;
  final VoidCallback onRewind;

  @override
  ConsumerState<_NotAMatchView> createState() => _NotAMatchViewState();
}

class _NotAMatchViewState extends ConsumerState<_NotAMatchView>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 10;
  late final AnimationController _animController;
  int _secondsRemaining = _totalSeconds;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
      value: 1.0,  // starts full
    );

    // Smooth progress bar
    _animController.animateTo(0.0, curve: Curves.linear);

    // 1-second tick just for the numeric label
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        widget.onSeeNext();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftValue = ref.watch(onboardingDraftProvider);
    final myImageUrl = draftValue.value?.profileImageUrl;
    final otherImageUrl = widget.result.interaction.fromUserProfileImageUrl;
    final otherName = widget.result.interaction.fromUserName?.trim()
        ?? widget.result.interaction.fromUserUsername?.trim()
        ?? 'Someone';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // ── Result Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBFF),
              borderRadius: BorderRadius.circular(44),
              border: Border.all(color: const Color(0xFFB18DFF), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Overlapping Avatars ─────────────────────────────────
                SizedBox(
                  height: 80,
                  width: 172,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left avatar (other person)
                      Positioned(
                        left: 0,
                        child: _PlayAvatar(imageUrl: otherImageUrl, size: 76),
                      ),
                      // Right avatar (me)
                      Positioned(
                        right: 0,
                        child: _PlayAvatar(imageUrl: myImageUrl, size: 76),
                      ),
                      // Centre question-mark badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '?',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB18DFF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Not a Match!',
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '$otherName chose something else.\nyou\'ll never know 😭',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF555555),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Rewind Button ──────────────────────────────────────────────
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB18DFF), Color(0xFF9060FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9060FF).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  if (ref.read(isProProvider)) {
                    widget.onRewind();
                  } else {
                    context.push('/pro');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      // Rewind icon box
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_counterclockwise,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rewind',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'go back and play again',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pro badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'pro',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFFB18DFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Thin separator
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFD0D0D0)),
          ),

          // ── Timer Row ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NEXT PROFILE IN',
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFFB18DFF),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${_secondsRemaining}s',
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFFB18DFF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Smooth Progress Bar ────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, __) => LinearProgressIndicator(
                value: _animController.value,
                backgroundColor: const Color(0xFFE8DFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB18DFF)),
                minHeight: 5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── See Next Profile Button ────────────────────────────────────
          GestureDetector(
            onTap: widget.onSeeNext,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFB18DFF), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See next profile',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.remainingCount.toString(),
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Color(0xFFB18DFF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    CupertinoIcons.arrow_right,
                    color: Colors.black87,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable avatar widget with loading & fallback
// ─────────────────────────────────────────────────────────────────────────────

class _PlayAvatar extends StatelessWidget {
  const _PlayAvatar({this.imageUrl, this.size = 72});
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
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFE8DFFF),
                    child: const Center(
                      child: CupertinoActivityIndicator(
                        color: Color(0xFFB18DFF),
                        radius: 10,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('[PlayAvatar] Error loading image: $error');
                  return _fallback();
                },
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: const Color(0xFFE0D8FF),
        child: const Icon(CupertinoIcons.person_solid, color: Colors.white, size: 36),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Play queue — main card view
// ─────────────────────────────────────────────────────────────────────────────

class _PlayQueue extends StatelessWidget {
  const _PlayQueue({
    required this.item,
    required this.remainingCount,
    required this.isSubmitting,
    required this.onSelect,
  });

  final InteractionRecord item;
  final int remainingCount;
  final bool isSubmitting;
  final ValueChanged<InteractionType> onSelect;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = item.fromUserProfileImageUrl;
    final name = (item.fromUserName?.trim().isNotEmpty == true
            ? item.fromUserName!.trim()
            : item.fromUserUsername?.trim().isNotEmpty == true
                ? item.fromUserUsername!.trim()
                : 'Someone');

    // Determine which social icon to show
    final socialIcon = _socialIcon(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),

          // ── "👀 reacted to you" pill ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E1FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmojiImage(emoji: '👀', size: 14),
                const SizedBox(width: 8),
                Text(
                  '$remainingCount reacted to you',
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Stacked card (scaled down) ────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final backW  = w * 0.7;
              final midW   = w * 0.88;
              final frontW = w;

              const frontCardH   = 195.0;
              const purpleHeaderH = 130.0;
              const avatarRadius = 52.0;
              const backTop  = 0.0;
              const midTop   = 10.0;
              const frontTop = 20.0;
              const avatarTop = frontTop - 40.0;

              final stackH = frontTop + frontCardH;

              return SizedBox(
                height: stackH,
                width: w,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Layer 1 — back
                    Positioned(
                      top: backTop,
                      child: Container(
                        width: backW,
                        height: frontCardH * 0.8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Layer 2 — mid
                    Positioned(
                      top: midTop,
                      child: Container(
                        width: midW,
                        height: frontCardH * 0.9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Layer 3 — front card
                    Positioned(
                      top: frontTop,
                      child: Container(
                        width: frontW,
                        height: frontCardH,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              Container(
                                height: purpleHeaderH,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFB18DFF), Color(0xFF9E6DFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 14,
                                      right: 16,
                                      child: Icon(
                                        CupertinoIcons.flag_fill,
                                        size: 18,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontFamily: TFonts.nunito,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'What do you think of me?',
                                    style: const TextStyle(
                                      fontFamily: TFonts.nunito,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Floating avatar
                    Positioned(
                      top: avatarTop,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: avatarRadius,
                              backgroundColor: const Color(0xFFAEE5F2),
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      name.characters.first.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 28,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (socialIcon != null)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Image.asset(
                                    socialIcon,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Response buttons ──────────────────────────────────────────────
          _ResponseButton(
            label: 'Friend',
            emoji: '🤝',
            colors: const [Color(0xFF00E1FF), Color(0xFF006BFF)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.friend),
          ),
          const SizedBox(height: 16),
          _ResponseButton(
            label: 'Crush',
            emoji: '😍',
            colors: const [Color(0xFFD34EDF), Color(0xFFFF3393)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.crush),
          ),
          const SizedBox(height: 16),
          _ResponseButton(
            label: 'Frenemy',
            emoji: '😈',
            colors: const [Color(0xFFB3A8E8), Color(0xFF535590)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.frenemy),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  String? _socialIcon(InteractionRecord item) {
    final insta = item.fromUserInstagramId ?? '';
    final snap  = item.fromUserSnapchatId  ?? '';
    if (insta.isNotEmpty) return TImages.instagramIcon;
    if (snap.isNotEmpty)  return TImages.snapchatIcon;
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Response button — full-width gradient pill
// ─────────────────────────────────────────────────────────────────────────────
class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.emoji,
    required this.colors,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final List<Color> colors;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextButton(
          onPressed: disabled ? null : onTap,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmojiImage(
                emoji: emoji,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty queue view
// ─────────────────────────────────────────────────────────────────────────────
class _CompletedQueueView extends StatelessWidget {
  const _CompletedQueueView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [PlayEmptyState()],
      ),
    );
  }
}

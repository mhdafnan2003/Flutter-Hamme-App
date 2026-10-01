import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/home/domain/models/share_instruction_data.dart';
import 'package:hamme_app/features/home/presentation/widgets/platform_pill.dart';
import 'package:hamme_app/features/home/presentation/widgets/share_action_button.dart';
import 'package:hamme_app/features/home/presentation/widgets/share_instruction_card.dart';
import 'package:hamme_app/features/home/presentation/widgets/share_instruction_preview.dart';
import 'package:hamme_app/features/home/presentation/widgets/share_instruction_title.dart';

class SharePreviewScreen extends ConsumerStatefulWidget {
  const SharePreviewScreen({super.key});

  @override
  ConsumerState<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends ConsumerState<SharePreviewScreen> {
  int _step = 1;
  bool _isInstagram = true;

  void _nextStep() {
    if (_step < 4) {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ShareInstructionData.forStep(_step, isInstagram: _isInstagram);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 16,
                  child: AppCloseCircleButton(
                    onPressed: () => context.go('/home'),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 393),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      PlatformPill(
                                        selected: _isInstagram,
                                        iconPath:
                                            'assets/icons/insta-outline.png',
                                        onTap: () {
                                          if (_isInstagram) return;
                                          setState(() {
                                            _isInstagram = true;
                                            _step = 1;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 28),
                                      PlatformPill(
                                        selected: !_isInstagram,
                                        iconPath: 'assets/icons/snap-fill.png',
                                        onTap: () {
                                          if (!_isInstagram) return;
                                          setState(() {
                                            _isInstagram = false;
                                            _step = 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  ShareInstructionCard(
                                    title: 'How to add the Link\nto your story',
                                    activeStep: _step,
                                    totalSteps: 4,
                                    instructionTitle: ShareInstructionTitle(
                                      data: data,
                                    ),
                                    image: ShareInstructionPreview(
                                      imagePath: data.imagePath,
                                    ),
                                    imageSpacing:
                                        data.highlight == 'LINK' ? 17 : 24,
                                    action: ShareActionButton(
                                      label: _step == 4 ? 'Share' : 'Next Step',
                                      iconPath:
                                          _step == 4
                                              ? (_isInstagram
                                                  ? 'assets/icons/insta-outline.png'
                                                  : 'assets/icons/snap-fill.png')
                                              : null,
                                      onTap:
                                          _step == 4
                                              ? () {
                                                ref
                                                    .read(
                                                      shareTutorialCompletionProvider
                                                          .notifier,
                                                    )
                                                    .markComplete();
                                                // Replace this page rather than `go`, so
                                                // the tab shell below stays alive (a
                                                // `go` would dispose and rebuild it).
                                                context.pushReplacement(
                                                  '/share/playing?autoShare=true&platform=${_isInstagram ? 'instagram' : 'snapchat'}',
                                                );
                                              }
                                              : _nextStep,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

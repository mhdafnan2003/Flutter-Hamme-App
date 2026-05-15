import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: const Color(0xFF5F5F5F),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              const Color(0xFF4A4A4A),
              const Color(0xFF2C2C2C),
              const Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 18,
                right: 18,
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Color(0xFF676767),
                      size: 22,
                    ),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 393),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlatformPill(
                              selected: _isInstagram,
                              iconPath: 'assets/icons/insta-outline.png',
                              onTap: () => setState(() => _isInstagram = true),
                            ),
                            const SizedBox(width: 28),
                            PlatformPill(
                              selected: !_isInstagram,
                              iconPath: 'assets/icons/snap-fill.png',
                              onTap: () => setState(() => _isInstagram = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ShareInstructionCard(
                          title: 'How to add the Link\nto your story',
                          activeStep: _step,
                          totalSteps: 4,
                          instructionTitle: ShareInstructionTitle(data: data),
                          image: ShareInstructionPreview(
                            step: _step,
                            isInstagram: _isInstagram,
                          ),
                          action: ShareActionButton(
                            label: _step == 4 ? 'Share' : 'Next Step',
                            iconPath: _step == 4
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
                                        context.go(
                                          '/share/playing?autoShare=true&platform=${_isInstagram ? 'instagram' : 'snapchat'}',
                                        );
                                      }
                                    : _nextStep,
                          ),
                        ),
                        const Spacer(flex: 1),
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

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';
import '../widgets/triangle_painter.dart';

class ProfileUploadScreen extends ConsumerStatefulWidget {
  const ProfileUploadScreen({super.key});

  @override
  ConsumerState<ProfileUploadScreen> createState() =>
      _ProfileUploadScreenState();
}

class _ProfileUploadScreenState extends ConsumerState<ProfileUploadScreen> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {
    'jpeg',
    'jpg',
    'png',
    'webp',
    'webg',
  };

  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final imagePath = ref.read(onboardingDraftProvider).value?.profileImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (kIsWeb) {
        setState(() {
          // On web we just store the path string
        });
      } else {
        final file = File(imagePath);
        if (file.existsSync()) {
          _selectedImage = file;
        }
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final fileName = pickedFile.name;
    final extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    if (!_allowedExtensions.contains(extension)) {
      _showMessage('Please upload a JPG, JPEG, PNG, WEBP, or WEBG image.');
      return;
    }

    final fileSize = await pickedFile.length();
    if (fileSize > _maxImageBytes) {
      _showMessage('Image size must be less than 10 MB.');
      return;
    }

    if (!mounted) return;
    setState(() {
      if (!kIsWeb) {
        _selectedImage = File(pickedFile.path);
      }
    });
    ref
        .read(onboardingDraftProvider.notifier)
        .setProfileImagePath(pickedFile.path);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DobTopBar(onBack: () => context.go('/onboarding/name'), progress: 0.75),
            const SizedBox(height: 30),
            const Text(
              TTexts.onboardingProfileTitle,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: TColors.black,
              ),
            ),
            const SizedBox(height: 12),
            const Text('📸', style: TextStyle(fontSize: 28)),

            const Spacer(),

            SizedBox(
              height: 280,
              width: 300,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 10,
                    right: 20,
                    child: Transform.rotate(
                      angle: -0.05,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TColors.hammePrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              CupertinoIcons.time_solid,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              TTexts.onboardingRecentPhoto,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 50,
                    left: 20,
                    child: Transform.rotate(
                      angle: -0.05,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TColors.hammePrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              CupertinoIcons.person_crop_rectangle_fill,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              TTexts.onboardingShowFace,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 85,
                    left: 140,
                    child: CustomPaint(
                      size: const Size(20, 15),
                      painter: TrianglePainter(color: TColors.hammePrimary),
                    ),
                  ),

                  Positioned(
                    top: 100,
                    left: 71,
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 158,
                            height: 158,
                            decoration: const BoxDecoration(
                              color: TColors.hammeSurface,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: ref.watch(onboardingDraftProvider).value?.profileImagePath == null
                                      ? const Icon(
                                        CupertinoIcons.person_solid,
                                        size: 80,
                                        color: Colors.black,
                                      )
                                      : kIsWeb
                                          ? Image.network(
                                            ref
                                                .watch(onboardingDraftProvider)
                                                .value!
                                                .profileImagePath!,
                                            fit: BoxFit.cover,
                                          )
                                          : Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                          ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: TColors.hammePrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.add,
                                color: Colors.white,
                                size: 24,
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

            const Spacer(),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                onTap: () {
                  context.go('/onboarding/social_media');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

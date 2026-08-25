import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../../../../../core/widgets/onboarding_validation_dialog.dart';
import '../widgets/dob_top_bar.dart';
import '../widgets/profile_avatar_stack.dart';

class ProfileUploadScreen extends ConsumerStatefulWidget {
  const ProfileUploadScreen({super.key});

  @override
  ConsumerState<ProfileUploadScreen> createState() =>
      _ProfileUploadScreenState();
}

class _ProfileUploadScreenState extends ConsumerState<ProfileUploadScreen> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpeg', 'jpg', 'png', 'webp'};
  static const double _progress = 152 / 170;

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _previewBytes;
  bool _isPickingImage = false;

  Future<void> _pickProfileImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile == null) return;

      final fileName = pickedFile.name;
      final extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      if (!_allowedExtensions.contains(extension)) {
        _showMessage('Please upload a JPG, JPEG, PNG, or WEBP image.');
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _showMessage('Image size must be less than 10 MB.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
      });
      ref.read(onboardingProfileImageProvider.notifier).state =
          OnboardingProfileImage(
            bytes: bytes,
            filename: fileName.isNotEmpty ? fileName : 'profile.jpg',
          );
    } finally {
      _isPickingImage = false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider).value;
    final profileImageUrl = draft?.profileImageUrl;
    final selectedImage = ref.watch(onboardingProfileImageProvider);

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DobTopBar(
              onBack: () => context.go('/onboarding/name'),
              progress: _progress,
            ),
            const SizedBox(height: 33),
            const Text(
              TTexts.onboardingProfileTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                height: 1,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 21),
            Image.asset(
              TImages.emojiCamera,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 74),
            ProfileAvatarStack(
              onPickImage: _pickProfileImage,
              previewBytes: _previewBytes,
              profileImageUrl: profileImageUrl,
              selectedImageBytes: selectedImage?.bytes,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                borderRadius: 22,
                fontWeight: FontWeight.w800,
                onTap: () async {
                  if ((profileImageUrl == null || profileImageUrl.isEmpty) &&
                      selectedImage == null) {
                    HapticFeedback.mediumImpact();
                    final shouldPickImage =
                        await showOnboardingValidationDialog(
                          context,
                          title: 'Add a profile photo',
                          message:
                              'Choose a clear photo of yourself before continuing.',
                          actionLabel: 'Choose photo',
                        );
                    if (shouldPickImage && mounted) await _pickProfileImage();
                    return;
                  }
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

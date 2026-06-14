import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';

import 'package:hamme_app/core/widgets/emoji_image.dart';
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
  };

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _previewBytes;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickProfileImage() async {
    if (_isUploading) return;
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
      _isUploading = true;
      _uploadError = null;
      _previewBytes = bytes;
    });

    try {
      final uploadDataSource = UploadRemoteDataSource(
        ref.read(apiServiceProvider),
      );
      final imageUrl = await uploadDataSource.uploadProfileImageBytes(
        bytes: bytes,
        filename: fileName.isNotEmpty ? fileName : 'profile.jpg',
      );
      await ref
          .read(onboardingDraftProvider.notifier)
          .setProfileImageUrl(imageUrl);
      if (!mounted) return;
      context.go('/onboarding/social_media');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = 'Upload failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
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
            const EmojiImage(emoji: '📸', size: 28),

            const Spacer(),

            SizedBox(
              height: 280,
              width: 300,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 10,
                    left: 50,
                    child: Transform.rotate(
                      angle: 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAC7AFF),
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
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 45,
                    left: 20,
                    child: Transform.rotate(
                      angle: -0.07,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAC7AFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/user_3.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              TTexts.onboardingShowFace,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 80,
                    left: 140,
                    child: CustomPaint(
                      size: const Size(20, 15),
                      painter: TrianglePainter(color: const Color(0xFFAC7AFF)),
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
                              child: profileImageUrl != null && profileImageUrl.isNotEmpty
                                  ? Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                  )
                                  : _previewBytes != null
                                      ? Image.memory(
                                        _previewBytes!,
                                        fit: BoxFit.cover,
                                      )
                                      : const Icon(
                                        CupertinoIcons.person_solid,
                                        size: 80,
                                        color: Colors.black,
                                      ),
                            ),
                          ),
                          if (_isUploading)
                            const Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9E57FF),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Image.asset(
                                  'assets/icons/icon_line/Plus.png',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_uploadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _uploadError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w700,
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

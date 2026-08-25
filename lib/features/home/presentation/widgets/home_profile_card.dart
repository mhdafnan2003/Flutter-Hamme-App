import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class HomeProfileCard extends ConsumerStatefulWidget {
  const HomeProfileCard({super.key});

  @override
  ConsumerState<HomeProfileCard> createState() => _HomeProfileCardState();
}

class _HomeProfileCardState extends ConsumerState<HomeProfileCard> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpeg', 'jpg', 'png', 'webp'};
  Uint8List? _lastLocalAvatarBytes;

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  // ignore: unused_element
  Future<void> _changeProfileImage() async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a JPG, JPEG, PNG, or WEBP image.'),
        ),
      );
      return;
    }

    final bytes = await pickedFile.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image size must be less than 10 MB.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = true);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft =
        ref.watch(onboardingDraftProvider).value ?? const OnboardingDraft();
    final profileName =
        (draft.name != null && draft.name!.trim().isNotEmpty)
            ? draft.name!.trim()
            : TTexts.homeProfileName;
    final profileImageUrl = draft.profileImageUrl;
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;
    // During onboarding, show the image the user just selected immediately.
    // The Cloudinary URL replaces this preview after the background upload
    // finishes.
    final selectedOnboardingImage = ref.watch(onboardingProfileImageProvider);
    if (selectedOnboardingImage != null) {
      _lastLocalAvatarBytes = selectedOnboardingImage.bytes;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: TColors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 134,
                decoration: const BoxDecoration(
                  color: Color(0xFFA678FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          profileName,
                          style: const TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: TColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  TTexts.homePrompt,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -53,
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TColors.hammeSurface,
                ),
                child:
                    selectedOnboardingImage != null
                        ? ClipOval(
                          child: Image.memory(
                            selectedOnboardingImage.bytes,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                        )
                        : hasProfileImage
                        ? ClipOval(
                          child: Image.network(
                            profileImageUrl,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress != null &&
                                  _lastLocalAvatarBytes != null) {
                                return Image.memory(
                                  _lastLocalAvatarBytes!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                );
                              }
                              return child;
                            },
                            frameBuilder: (context, child, frame, _) {
                              if (frame != null &&
                                  _lastLocalAvatarBytes != null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(
                                      () => _lastLocalAvatarBytes = null,
                                    );
                                  }
                                });
                              }
                              return child;
                            },
                          ),
                        )
                        : const Icon(
                          CupertinoIcons.person_solid,
                          size: 60,
                          color: TColors.grey,
                        ),
              ),
              if (draft.socialPlatform != null &&
                  draft.socialPlatform!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      draft.socialPlatform == TTexts.socialInstagram
                          ? TImages.instagramIcon
                          : TImages.snapchatIcon,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color:
                                draft.socialPlatform == TTexts.socialSnapchat
                                    ? TColors.snapchatYellow
                                    : TColors.hammePrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            draft.socialPlatform == TTexts.socialInstagram
                                ? CupertinoIcons.camera_fill
                                : CupertinoIcons.chat_bubble_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

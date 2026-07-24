import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class HomeProfileCard extends ConsumerStatefulWidget {
  const HomeProfileCard({super.key});

  @override
  ConsumerState<HomeProfileCard> createState() => _HomeProfileCardState();
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit your name',
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 23,
                color: TColors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is how your profile appears in Hamme.',
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: TColors.darkGrey,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Your name',
                hintStyle: const TextStyle(
                  fontFamily: TFonts.nunito,
                  color: TColors.grey,
                ),
                filled: true,
                fillColor: TColors.hammeSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: TColors.hammePrimary,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w800,
                        color: TColors.darkGrey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9E57FF), Color(0xFF8B44FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeProfileCardState extends ConsumerState<HomeProfileCard> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpeg', 'jpg', 'png', 'webp'};

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isUpdatingName = false;

  // Kept temporarily for compatibility with the existing profile-card state;
  // editing is now exposed exclusively from ProfileScreen.
  // ignore: unused_element
  Future<void> _editProfileName(String currentName) async {
    if (_isUpdatingName) return;

    final updatedName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: currentName),
    );

    if (updatedName == null || updatedName.isEmpty || updatedName == currentName) {
      return;
    }

    setState(() => _isUpdatingName = true);
    try {
      await ProfileRemoteDataSource(ref.read(apiServiceProvider)).updateMe(
        name: updatedName,
      );
      await ref.read(onboardingDraftProvider.notifier).setName(updatedName);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your name. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

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
        const SnackBar(content: Text('Please upload a JPG, JPEG, PNG, or WEBP image.')),
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
      await ref.read(onboardingDraftProvider.notifier).setProfileImageUrl(imageUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated!')),
      );
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
    final draft = ref.watch(onboardingDraftProvider).value ?? const OnboardingDraft();
    final profileName =
        (draft.name != null && draft.name!.trim().isNotEmpty)
            ? draft.name!.trim()
            : TTexts.homeProfileName;
    final profileImageUrl = draft.profileImageUrl;
    final hasProfileImage =
      profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: TColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: const BoxDecoration(
                  color: TColors.hammePrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
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
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  TTexts.homePrompt,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: TColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -50,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TColors.hammeSurface,
                ),
                child: hasProfileImage
                    ? ClipOval(
                      child: Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                      ),
                    )
                    : const Icon(
                  CupertinoIcons.person_solid,
                  size: 50,
                  color: TColors.grey,
                ),
              ),
        if (draft.socialPlatform != null && draft.socialPlatform!.isNotEmpty)
          Positioned(
            bottom: -5,
            right: -5,
            child: SizedBox(
              width: 45,
              height: 45,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Image.asset(
                  draft.socialPlatform == TTexts.socialInstagram
                      ? TImages.instagramIcon
                      : TImages.snapchatIcon,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: draft.socialPlatform == TTexts.socialSnapchat
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
          ),
            ],
          ),
        ),
      ],
    );
  }
}

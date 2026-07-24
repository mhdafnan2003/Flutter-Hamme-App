import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hamme_app/features/profile/data/datasources/upload_remote_data_source.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileTextEditDialog extends StatefulWidget {
  const _ProfileTextEditDialog({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.username,
  });

  final String title;
  final String hint;
  final String initialValue;
  final bool username;

  @override
  State<_ProfileTextEditDialog> createState() => _ProfileTextEditDialogState();
}

class _ProfileTextEditDialogState extends State<_ProfileTextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
            Text(widget.title, style: const TextStyle(fontFamily: TFonts.nunito, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: widget.username ? 32 : 80,
              textCapitalization: widget.username ? TextCapitalization.none : TextCapitalization.words,
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
                filled: true,
                fillColor: TColors.hammeSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: TColors.hammePrimary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF9E57FF), Color(0xFF8B44FF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextButton(
                    onPressed: _save,
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontFamily: TFonts.nunito, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isSaving = false;

  Future<String?> _showEditDialog({
    required String title,
    required String hint,
    required String initialValue,
    bool username = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ProfileTextEditDialog(
        title: title,
        hint: hint,
        initialValue: initialValue,
        username: username,
      ),
    );
  }

  Future<void> _saveName(String currentName) async {
    final name = await _showEditDialog(
      title: 'Edit your name',
      hint: 'Your name',
      initialValue: currentName,
    );
    if (name == null || name.isEmpty || name == currentName) return;
    await _saveProfile(
      action: () => ProfileRemoteDataSource(ref.read(apiServiceProvider)).updateMe(name: name),
      onSuccess: () => ref.read(onboardingDraftProvider.notifier).setName(name),
      successMessage: 'Name updated!',
    );
  }

  Future<void> _saveSocialUsername({
    required String currentUsername,
    required bool isInstagram,
  }) async {
    final username = await _showEditDialog(
      title: isInstagram ? 'Edit Instagram username' : 'Edit Snapchat username',
      hint: isInstagram ? 'Instagram username' : 'Snapchat username',
      initialValue: currentUsername.replaceFirst(RegExp(r'^@'), ''),
      username: true,
    );
    if (username == null || username.isEmpty ||
        username == currentUsername.replaceFirst(RegExp(r'^@'), '')) return;

    await _saveProfile(
      action: () => ProfileRemoteDataSource(ref.read(apiServiceProvider)).updateMe(
        instagramId: isInstagram ? username : null,
        snapchatId: isInstagram ? null : username,
        username: username,
      ),
      onSuccess: () => ref.read(onboardingDraftProvider.notifier).setSocial(
        platform: isInstagram ? TTexts.socialInstagram : TTexts.socialSnapchat,
        username: username,
      ),
      successMessage: 'Username updated!',
    );
  }

  Future<void> _saveProfile({
    required Future<void> Function() action,
    required Future<void> Function() onSuccess,
    required String successMessage,
  }) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await action();
      await onSuccess();
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your profile. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeProfileImage() async {
    if (_isUploadingImage) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final imageUrl = await UploadRemoteDataSource(ref.read(apiServiceProvider))
          .uploadProfileImageBytes(bytes: await image.readAsBytes(), filename: image.name);
      await ProfileRemoteDataSource(ref.read(apiServiceProvider)).updateMe(avatarUrl: imageUrl);
      await ref.read(onboardingDraftProvider.notifier).setProfileImageUrl(imageUrl);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your profile photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final draft = ref.watch(onboardingDraftProvider).value;
    final isPro = ref.watch(isProProvider);

    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Your Profile';
    final isInstagram = draft?.socialPlatform == TTexts.socialInstagram ||
        (draft?.socialPlatform == null && (user?.instagramId.isNotEmpty ?? false));
    final socialUsername = draft?.username?.isNotEmpty == true
        ? draft!.username!
        : (isInstagram ? user?.instagramId ?? '' : '');
    final handle = socialUsername.isNotEmpty ? '@${socialUsername.replaceFirst('@', '')}' : '';

    // The uploaded image URL is reliably stored in the onboarding draft, so we
    // prefer the account image and fall back to the draft (same source the
    // home card uses).
    final profileImageUrl =
        (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
            ? user.avatarUrl
            : draft?.profileImageUrl;
    final hasProfileImage = profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.left_chevron,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(TImages.hammeHomeLogo, height: 32),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Avatar ────────────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: TColors.hammePrimary, width: 3),
                    color: TColors.hammeSurface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasProfileImage
                      ? Image.network(profileImageUrl, fit: BoxFit.cover)
                      : const Icon(
                          CupertinoIcons.person_solid,
                          size: 56,
                          color: TColors.grey,
                        ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: _isUploadingImage ? null : _changeProfileImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: TColors.hammePrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: TColors.white, width: 3),
                      ),
                      child: _isUploadingImage
                          ? const CupertinoActivityIndicator(color: Colors.white, radius: 9)
                          : const Icon(CupertinoIcons.pencil, color: Colors.white, size: 17),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: TColors.black,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSaving ? null : () => _saveName(name),
                  child: const Icon(CupertinoIcons.pencil, size: 18, color: TColors.hammePrimary),
                ),
              ],
            ),
            if (handle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    handle,
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: TColors.darkGrey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isSaving
                        ? null
                        : () => _saveSocialUsername(
                              currentUsername: socialUsername,
                              isInstagram: isInstagram,
                            ),
                    child: const Icon(CupertinoIcons.pencil, size: 15, color: TColors.hammePrimary),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── Plan status ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isPro ? const Color(0xFFF1F0FD) : TColors.hammeSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPro ? const Color(0xFF9E57FF) : TColors.grey,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    size: 16,
                    color: isPro ? const Color(0xFF9E57FF) : TColors.darkGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPro ? 'Pro Plan' : 'Free Plan',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isPro ? const Color(0xFF8B44FF) : TColors.darkerGrey,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Upgrade to Pro ────────────────────────────────────────────
            if (!isPro)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => context.push('/pro'),
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9E57FF), Color(0xFF8B44FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9E57FF).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.star_fill, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to Pro',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

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
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpeg', 'jpg', 'png', 'webp'};

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isLoggingOut = false;

  Future<void> _logoutForOnboardingPreview() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
      // The router redirects signed-out users to onboarding automatically.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _changeProfileImage() async {
    if (_isUploadingImage) return;
    // Set before the picker opens: a second tap while it is open would start
    // another picker, which throws.
    setState(() => _isUploadingImage = true);
    try {
      // The server stores at most 1024 px (JPEG, quality 80), so sending a
      // larger image only costs upload time.
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;

      final fileName = image.name;
      final extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      if (!_allowedExtensions.contains(extension)) {
        _showMessage('Please upload a JPG, JPEG, PNG, or WEBP image.');
        return;
      }

      final bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _showMessage('Image size must be less than 10 MB.');
        return;
      }
      if (!mounted) return;

      // Read before the requests so the result is applied even if the user
      // leaves this screen while they run.
      final apiService = ref.read(apiServiceProvider);
      final draftNotifier = ref.read(onboardingDraftProvider.notifier);
      final authController = ref.read(authControllerProvider.notifier);
      final imageUrl = await UploadRemoteDataSource(
        apiService,
      ).uploadProfileImageBytes(bytes: bytes, filename: fileName);
      // PATCH /profiles/me returns the updated user, so no refetch is needed.
      final updatedUser = await ProfileRemoteDataSource(
        apiService,
      ).updateMe(avatarUrl: imageUrl);
      await draftNotifier.setProfileImageUrl(imageUrl);
      authController.setUser(updatedUser);
      _showMessage('Profile photo updated!');
    } catch (_) {
      _showMessage('Could not update your profile photo.');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
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
    final user = ref.watch(authControllerProvider).value?.user;
    final draft = ref.watch(onboardingDraftProvider).value;
    final isPro = ref.watch(isProProvider);

    final name =
        (user?.name.trim().isNotEmpty ?? false)
            ? user!.name.trim()
            : 'Your Profile';
    final isInstagram =
        draft?.socialPlatform == TTexts.socialInstagram ||
        (draft?.socialPlatform == null &&
            (user?.instagramId.isNotEmpty ?? false));
    final socialUsername =
        draft?.username?.isNotEmpty == true
            ? draft!.username!
            : (isInstagram ? user?.instagramId ?? '' : '');
    final handle =
        socialUsername.isNotEmpty
            ? '@${socialUsername.replaceFirst('@', '')}'
            : '';

    // The uploaded image URL is reliably stored in the onboarding draft, so we
    // prefer the account image and fall back to the draft (same source the
    // home card uses).
    final profileImageUrl =
        (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
            ? user.avatarUrl
            : draft?.profileImageUrl;
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;

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
                    onTap:
                        () =>
                            context.canPop()
                                ? context.pop()
                                : context.go('/home'),
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
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F7),
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(
                      CupertinoIcons.gear_solid,
                      color: Colors.black,
                      size: 21,
                    ),
                  ),
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
                  child:
                      hasProfileImage
                          ? Padding(
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Transform.scale(
                                scale: 1.08,
                                child: Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
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
                      child:
                          _isUploadingImage
                              ? const CupertinoActivityIndicator(
                                color: Colors.white,
                                radius: 9,
                              )
                              : const Icon(
                                CupertinoIcons.pencil,
                                color: Colors.white,
                                size: 17,
                              ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              name,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: TColors.black,
              ),
            ),
            if (handle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                handle,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: TColors.darkGrey,
                ),
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
                      color:
                          isPro ? const Color(0xFF8B44FF) : TColors.darkerGrey,
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
                        Icon(
                          CupertinoIcons.star_fill,
                          color: Colors.white,
                          size: 20,
                        ),
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

            if (AppConstants.showDeveloperLogoutButton) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _isLoggingOut ? null : _logoutForOnboardingPreview,
                icon:
                    _isLoggingOut
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                        : const Icon(CupertinoIcons.arrow_right_square),
                label: Text(_isLoggingOut ? 'Logging out…' : 'Log out (dev)'),
                style: TextButton.styleFrom(
                  foregroundColor: TColors.darkGrey,
                  textStyle: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

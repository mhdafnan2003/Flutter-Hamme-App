import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDraft {
  const OnboardingDraft({
    this.name,
    this.birthday,
    this.socialPlatform,
    this.username,
    this.profileImagePath,
  });

  final String? name;
  final DateTime? birthday;
  final String? socialPlatform;
  final String? username;
  final String? profileImagePath;

  OnboardingDraft copyWith({
    String? name,
    DateTime? birthday,
    String? socialPlatform,
    String? username,
    String? profileImagePath,
  }) {
    return OnboardingDraft(
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      socialPlatform: socialPlatform ?? this.socialPlatform,
      username: username ?? this.username,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }
}

class OnboardingDraftNotifier extends AsyncNotifier<OnboardingDraft> {
  static const _nameKey = 'onboarding_name';
  static const _birthdayKey = 'onboarding_birthday';
  static const _socialPlatformKey = 'onboarding_social_platform';
  static const _usernameKey = 'onboarding_username';
  static const _profileImageKey = 'onboarding_profile_image';

  @override
  Future<OnboardingDraft> build() async {
    final prefs = await SharedPreferences.getInstance();
    
    final birthdayStr = prefs.getString(_birthdayKey);
    final birthday = birthdayStr != null ? DateTime.parse(birthdayStr) : null;

    return OnboardingDraft(
      name: prefs.getString(_nameKey),
      birthday: birthday,
      socialPlatform: prefs.getString(_socialPlatformKey),
      username: prefs.getString(_usernameKey),
      profileImagePath: prefs.getString(_profileImageKey),
    );
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    state = AsyncData(state.value!.copyWith(name: name));
  }

  Future<void> setBirthday(DateTime birthday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_birthdayKey, birthday.toIso8601String());
    state = AsyncData(state.value!.copyWith(birthday: birthday));
  }

  Future<void> setSocial({required String platform, required String username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_socialPlatformKey, platform);
    await prefs.setString(_usernameKey, username);
    state = AsyncData(state.value!.copyWith(socialPlatform: platform, username: username));
  }

  Future<void> setProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey, path);
    state = AsyncData(state.value!.copyWith(profileImagePath: path));
  }
}

final onboardingDraftProvider =
    AsyncNotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

final onboardingCompletionProvider =
    AsyncNotifierProvider<OnboardingCompletionNotifier, bool>(
      OnboardingCompletionNotifier.new,
    );

class OnboardingCompletionNotifier extends AsyncNotifier<bool> {
  static const _onboardingCompleteKey = 'onboarding_complete';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> markComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompleteKey, true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompleteKey, false);
    state = const AsyncData(false);
  }
}

class ShareTutorialCompletionNotifier extends AsyncNotifier<bool> {
  static const _shareTutorialCompleteKey = 'share_tutorial_complete';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_shareTutorialCompleteKey) ?? false;
  }

  Future<void> markComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_shareTutorialCompleteKey, true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_shareTutorialCompleteKey, false);
    state = const AsyncData(false);
  }
}

final shareTutorialCompletionProvider =
    AsyncNotifierProvider<ShareTutorialCompletionNotifier, bool>(
      ShareTutorialCompletionNotifier.new,
    );

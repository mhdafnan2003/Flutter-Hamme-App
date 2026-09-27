import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/constants/app_constants.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
abstract class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String id,
    required String name,
    required String email,
    required String instagramId,
    @Default('') String snapchatId,
    String? avatarUrl,
    required String shareCode,
    @Default(false) bool isPro,
    // The terms/ban fields are parsed leniently: an unexpected type from the
    // backend must never make the whole user (and so the session) unreadable.
    @JsonKey(fromJson: _dateTimeOrNull) DateTime? termsAcceptedAt,
    @JsonKey(fromJson: _intOrNull) int? termsVersion,
    @Default(false) @JsonKey(fromJson: _boolOrFalse) bool isBanned,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  /// Whether this user has agreed to the current Terms of Use and Community
  /// Guidelines ([kCurrentTermsVersion]).
  bool get hasAcceptedCurrentTerms =>
      termsVersion != null && termsVersion! >= kCurrentTermsVersion;
}

DateTime? _dateTimeOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _boolOrFalse(Object? value) => value == true;

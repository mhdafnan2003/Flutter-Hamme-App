// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  instagramId: json['instagramId'] as String,
  snapchatId: json['snapchatId'] as String? ?? '',
  avatarUrl: json['avatarUrl'] as String?,
  shareCode: json['shareCode'] as String,
  isPro: json['isPro'] as bool? ?? false,
  termsAcceptedAt: _dateTimeOrNull(json['termsAcceptedAt']),
  termsVersion: _intOrNull(json['termsVersion']),
  isBanned: json['isBanned'] == null ? false : _boolOrFalse(json['isBanned']),
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'instagramId': instance.instagramId,
  'snapchatId': instance.snapchatId,
  'avatarUrl': instance.avatarUrl,
  'shareCode': instance.shareCode,
  'isPro': instance.isPro,
  'termsAcceptedAt': instance.termsAcceptedAt?.toIso8601String(),
  'termsVersion': instance.termsVersion,
  'isBanned': instance.isBanned,
};

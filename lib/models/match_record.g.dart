// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchRecord _$MatchRecordFromJson(Map<String, dynamic> json) => _MatchRecord(
  id: json['id'] as String,
  type: $enumDecode(_$InteractionTypeEnumMap, json['type']),
  matchedUser: AppUser.fromJson(json['matchedUser'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MatchRecordToJson(_MatchRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$InteractionTypeEnumMap[instance.type]!,
      'matchedUser': instance.matchedUser,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$InteractionTypeEnumMap = {
  InteractionType.crush: 'crush',
  InteractionType.friend: 'friend',
  InteractionType.frenemy: 'frenemy',
};

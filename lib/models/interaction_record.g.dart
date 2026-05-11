// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interaction_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InteractionRecord _$InteractionRecordFromJson(Map<String, dynamic> json) =>
    _InteractionRecord(
      id: json['id'] as String,
      fromUser: json['fromUser'] as String?,
      toUser: json['toUser'] as String,
      type: $enumDecode(_$InteractionTypeEnumMap, json['type']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$InteractionRecordToJson(_InteractionRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromUser': instance.fromUser,
      'toUser': instance.toUser,
      'type': _$InteractionTypeEnumMap[instance.type]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$InteractionTypeEnumMap = {
  InteractionType.crush: 'crush',
  InteractionType.friend: 'friend',
  InteractionType.frenemy: 'frenemy',
  InteractionType.ameny: 'ameny',
};

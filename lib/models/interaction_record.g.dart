// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interaction_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InteractionRecord _$InteractionRecordFromJson(Map<String, dynamic> json) =>
    _InteractionRecord(
      id: json['id'] as String,
      fromUser: json['fromUser'] as String?,
      fromUserName: json['fromUserName'] as String?,
      fromUserUsername: json['fromUserUsername'] as String?,
      fromUserProfileImageUrl: json['fromUserProfileImageUrl'] as String?,
      fromUserShareCode: json['fromUserShareCode'] as String?,
      fromUserInstagramId: json['fromUserInstagramId'] as String?,
      fromUserSnapchatId: json['fromUserSnapchatId'] as String?,
      toUser: json['toUser'] as String,
      type: $enumDecode(_$InteractionTypeEnumMap, json['type']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      respondedByCurrentUser: json['respondedByCurrentUser'] as bool? ?? false,
      matched: json['matched'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$InteractionRecordToJson(_InteractionRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromUser': instance.fromUser,
      'fromUserName': instance.fromUserName,
      'fromUserUsername': instance.fromUserUsername,
      'fromUserProfileImageUrl': instance.fromUserProfileImageUrl,
      'fromUserShareCode': instance.fromUserShareCode,
      'fromUserInstagramId': instance.fromUserInstagramId,
      'fromUserSnapchatId': instance.fromUserSnapchatId,
      'toUser': instance.toUser,
      'type': _$InteractionTypeEnumMap[instance.type]!,
      'metadata': instance.metadata,
      'respondedByCurrentUser': instance.respondedByCurrentUser,
      'matched': instance.matched,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$InteractionTypeEnumMap = {
  InteractionType.crush: 'crush',
  InteractionType.friend: 'friend',
  InteractionType.frenemy: 'frenemy',
};

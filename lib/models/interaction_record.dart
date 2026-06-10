import 'package:freezed_annotation/freezed_annotation.dart';

import 'interaction_type.dart';

part 'interaction_record.freezed.dart';
part 'interaction_record.g.dart';

@freezed
abstract class InteractionRecord with _$InteractionRecord {
  const factory InteractionRecord({
    required String id,
    String? fromUser,
    String? fromUserName,
    String? fromUserUsername,
    String? fromUserProfileImageUrl,
    String? fromUserShareCode,
    String? fromUserInstagramId,
    String? fromUserSnapchatId,
    required String toUser,
    required InteractionType type,
    Map<String, dynamic>? metadata,
    @Default(false) bool respondedByCurrentUser,
    @Default(false) bool matched,
    required DateTime createdAt,
  }) = _InteractionRecord;

  factory InteractionRecord.fromJson(Map<String, dynamic> json) =>
      _$InteractionRecordFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

import 'interaction_type.dart';

part 'interaction_record.freezed.dart';
part 'interaction_record.g.dart';

@freezed
abstract class InteractionRecord with _$InteractionRecord {
  const factory InteractionRecord({
    required String id,
    String? fromUser,
    required String toUser,
    required InteractionType type,
    required DateTime createdAt,
  }) = _InteractionRecord;

  factory InteractionRecord.fromJson(Map<String, dynamic> json) =>
      _$InteractionRecordFromJson(json);
}

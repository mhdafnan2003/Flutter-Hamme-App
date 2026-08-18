import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_user.dart';
import 'interaction_type.dart';

part 'match_record.freezed.dart';
part 'match_record.g.dart';

@freezed
abstract class MatchRecord with _$MatchRecord {
  const factory MatchRecord({
    required String id,
    required InteractionType type,
    required AppUser matchedUser,
    required DateTime createdAt,
    @Default(false) bool anonymous,
  }) = _MatchRecord;

  factory MatchRecord.fromJson(Map<String, dynamic> json) =>
      _$MatchRecordFromJson(json);
}

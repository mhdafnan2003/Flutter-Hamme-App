// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'interaction_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InteractionRecord {

 String get id; String? get fromUser; String? get fromUserName; String? get fromUserUsername; String? get fromUserProfileImageUrl; String? get fromUserShareCode; String? get fromUserInstagramId; String? get fromUserSnapchatId; String get toUser; InteractionType get type; Map<String, dynamic>? get metadata; bool get respondedByCurrentUser; bool get matched; DateTime get createdAt;
/// Create a copy of InteractionRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractionRecordCopyWith<InteractionRecord> get copyWith => _$InteractionRecordCopyWithImpl<InteractionRecord>(this as InteractionRecord, _$identity);

  /// Serializes this InteractionRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractionRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.fromUser, fromUser) || other.fromUser == fromUser)&&(identical(other.fromUserName, fromUserName) || other.fromUserName == fromUserName)&&(identical(other.fromUserUsername, fromUserUsername) || other.fromUserUsername == fromUserUsername)&&(identical(other.fromUserProfileImageUrl, fromUserProfileImageUrl) || other.fromUserProfileImageUrl == fromUserProfileImageUrl)&&(identical(other.fromUserShareCode, fromUserShareCode) || other.fromUserShareCode == fromUserShareCode)&&(identical(other.fromUserInstagramId, fromUserInstagramId) || other.fromUserInstagramId == fromUserInstagramId)&&(identical(other.fromUserSnapchatId, fromUserSnapchatId) || other.fromUserSnapchatId == fromUserSnapchatId)&&(identical(other.toUser, toUser) || other.toUser == toUser)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&(identical(other.respondedByCurrentUser, respondedByCurrentUser) || other.respondedByCurrentUser == respondedByCurrentUser)&&(identical(other.matched, matched) || other.matched == matched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromUser,fromUserName,fromUserUsername,fromUserProfileImageUrl,fromUserShareCode,fromUserInstagramId,fromUserSnapchatId,toUser,type,const DeepCollectionEquality().hash(metadata),respondedByCurrentUser,matched,createdAt);

@override
String toString() {
  return 'InteractionRecord(id: $id, fromUser: $fromUser, fromUserName: $fromUserName, fromUserUsername: $fromUserUsername, fromUserProfileImageUrl: $fromUserProfileImageUrl, fromUserShareCode: $fromUserShareCode, fromUserInstagramId: $fromUserInstagramId, fromUserSnapchatId: $fromUserSnapchatId, toUser: $toUser, type: $type, metadata: $metadata, respondedByCurrentUser: $respondedByCurrentUser, matched: $matched, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $InteractionRecordCopyWith<$Res>  {
  factory $InteractionRecordCopyWith(InteractionRecord value, $Res Function(InteractionRecord) _then) = _$InteractionRecordCopyWithImpl;
@useResult
$Res call({
 String id, String? fromUser, String? fromUserName, String? fromUserUsername, String? fromUserProfileImageUrl, String? fromUserShareCode, String? fromUserInstagramId, String? fromUserSnapchatId, String toUser, InteractionType type, Map<String, dynamic>? metadata, bool respondedByCurrentUser, bool matched, DateTime createdAt
});




}
/// @nodoc
class _$InteractionRecordCopyWithImpl<$Res>
    implements $InteractionRecordCopyWith<$Res> {
  _$InteractionRecordCopyWithImpl(this._self, this._then);

  final InteractionRecord _self;
  final $Res Function(InteractionRecord) _then;

/// Create a copy of InteractionRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fromUser = freezed,Object? fromUserName = freezed,Object? fromUserUsername = freezed,Object? fromUserProfileImageUrl = freezed,Object? fromUserShareCode = freezed,Object? fromUserInstagramId = freezed,Object? fromUserSnapchatId = freezed,Object? toUser = null,Object? type = null,Object? metadata = freezed,Object? respondedByCurrentUser = null,Object? matched = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromUser: freezed == fromUser ? _self.fromUser : fromUser // ignore: cast_nullable_to_non_nullable
as String?,fromUserName: freezed == fromUserName ? _self.fromUserName : fromUserName // ignore: cast_nullable_to_non_nullable
as String?,fromUserUsername: freezed == fromUserUsername ? _self.fromUserUsername : fromUserUsername // ignore: cast_nullable_to_non_nullable
as String?,fromUserProfileImageUrl: freezed == fromUserProfileImageUrl ? _self.fromUserProfileImageUrl : fromUserProfileImageUrl // ignore: cast_nullable_to_non_nullable
as String?,fromUserShareCode: freezed == fromUserShareCode ? _self.fromUserShareCode : fromUserShareCode // ignore: cast_nullable_to_non_nullable
as String?,fromUserInstagramId: freezed == fromUserInstagramId ? _self.fromUserInstagramId : fromUserInstagramId // ignore: cast_nullable_to_non_nullable
as String?,fromUserSnapchatId: freezed == fromUserSnapchatId ? _self.fromUserSnapchatId : fromUserSnapchatId // ignore: cast_nullable_to_non_nullable
as String?,toUser: null == toUser ? _self.toUser : toUser // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as InteractionType,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,respondedByCurrentUser: null == respondedByCurrentUser ? _self.respondedByCurrentUser : respondedByCurrentUser // ignore: cast_nullable_to_non_nullable
as bool,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [InteractionRecord].
extension InteractionRecordPatterns on InteractionRecord {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InteractionRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InteractionRecord() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InteractionRecord value)  $default,){
final _that = this;
switch (_that) {
case _InteractionRecord():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InteractionRecord value)?  $default,){
final _that = this;
switch (_that) {
case _InteractionRecord() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? fromUser,  String? fromUserName,  String? fromUserUsername,  String? fromUserProfileImageUrl,  String? fromUserShareCode,  String? fromUserInstagramId,  String? fromUserSnapchatId,  String toUser,  InteractionType type,  Map<String, dynamic>? metadata,  bool respondedByCurrentUser,  bool matched,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InteractionRecord() when $default != null:
return $default(_that.id,_that.fromUser,_that.fromUserName,_that.fromUserUsername,_that.fromUserProfileImageUrl,_that.fromUserShareCode,_that.fromUserInstagramId,_that.fromUserSnapchatId,_that.toUser,_that.type,_that.metadata,_that.respondedByCurrentUser,_that.matched,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? fromUser,  String? fromUserName,  String? fromUserUsername,  String? fromUserProfileImageUrl,  String? fromUserShareCode,  String? fromUserInstagramId,  String? fromUserSnapchatId,  String toUser,  InteractionType type,  Map<String, dynamic>? metadata,  bool respondedByCurrentUser,  bool matched,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _InteractionRecord():
return $default(_that.id,_that.fromUser,_that.fromUserName,_that.fromUserUsername,_that.fromUserProfileImageUrl,_that.fromUserShareCode,_that.fromUserInstagramId,_that.fromUserSnapchatId,_that.toUser,_that.type,_that.metadata,_that.respondedByCurrentUser,_that.matched,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? fromUser,  String? fromUserName,  String? fromUserUsername,  String? fromUserProfileImageUrl,  String? fromUserShareCode,  String? fromUserInstagramId,  String? fromUserSnapchatId,  String toUser,  InteractionType type,  Map<String, dynamic>? metadata,  bool respondedByCurrentUser,  bool matched,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _InteractionRecord() when $default != null:
return $default(_that.id,_that.fromUser,_that.fromUserName,_that.fromUserUsername,_that.fromUserProfileImageUrl,_that.fromUserShareCode,_that.fromUserInstagramId,_that.fromUserSnapchatId,_that.toUser,_that.type,_that.metadata,_that.respondedByCurrentUser,_that.matched,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InteractionRecord implements InteractionRecord {
  const _InteractionRecord({required this.id, this.fromUser, this.fromUserName, this.fromUserUsername, this.fromUserProfileImageUrl, this.fromUserShareCode, this.fromUserInstagramId, this.fromUserSnapchatId, required this.toUser, required this.type, final  Map<String, dynamic>? metadata, this.respondedByCurrentUser = false, this.matched = false, required this.createdAt}): _metadata = metadata;
  factory _InteractionRecord.fromJson(Map<String, dynamic> json) => _$InteractionRecordFromJson(json);

@override final  String id;
@override final  String? fromUser;
@override final  String? fromUserName;
@override final  String? fromUserUsername;
@override final  String? fromUserProfileImageUrl;
@override final  String? fromUserShareCode;
@override final  String? fromUserInstagramId;
@override final  String? fromUserSnapchatId;
@override final  String toUser;
@override final  InteractionType type;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool respondedByCurrentUser;
@override@JsonKey() final  bool matched;
@override final  DateTime createdAt;

/// Create a copy of InteractionRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractionRecordCopyWith<_InteractionRecord> get copyWith => __$InteractionRecordCopyWithImpl<_InteractionRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractionRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractionRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.fromUser, fromUser) || other.fromUser == fromUser)&&(identical(other.fromUserName, fromUserName) || other.fromUserName == fromUserName)&&(identical(other.fromUserUsername, fromUserUsername) || other.fromUserUsername == fromUserUsername)&&(identical(other.fromUserProfileImageUrl, fromUserProfileImageUrl) || other.fromUserProfileImageUrl == fromUserProfileImageUrl)&&(identical(other.fromUserShareCode, fromUserShareCode) || other.fromUserShareCode == fromUserShareCode)&&(identical(other.fromUserInstagramId, fromUserInstagramId) || other.fromUserInstagramId == fromUserInstagramId)&&(identical(other.fromUserSnapchatId, fromUserSnapchatId) || other.fromUserSnapchatId == fromUserSnapchatId)&&(identical(other.toUser, toUser) || other.toUser == toUser)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&(identical(other.respondedByCurrentUser, respondedByCurrentUser) || other.respondedByCurrentUser == respondedByCurrentUser)&&(identical(other.matched, matched) || other.matched == matched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromUser,fromUserName,fromUserUsername,fromUserProfileImageUrl,fromUserShareCode,fromUserInstagramId,fromUserSnapchatId,toUser,type,const DeepCollectionEquality().hash(_metadata),respondedByCurrentUser,matched,createdAt);

@override
String toString() {
  return 'InteractionRecord(id: $id, fromUser: $fromUser, fromUserName: $fromUserName, fromUserUsername: $fromUserUsername, fromUserProfileImageUrl: $fromUserProfileImageUrl, fromUserShareCode: $fromUserShareCode, fromUserInstagramId: $fromUserInstagramId, fromUserSnapchatId: $fromUserSnapchatId, toUser: $toUser, type: $type, metadata: $metadata, respondedByCurrentUser: $respondedByCurrentUser, matched: $matched, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$InteractionRecordCopyWith<$Res> implements $InteractionRecordCopyWith<$Res> {
  factory _$InteractionRecordCopyWith(_InteractionRecord value, $Res Function(_InteractionRecord) _then) = __$InteractionRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String? fromUser, String? fromUserName, String? fromUserUsername, String? fromUserProfileImageUrl, String? fromUserShareCode, String? fromUserInstagramId, String? fromUserSnapchatId, String toUser, InteractionType type, Map<String, dynamic>? metadata, bool respondedByCurrentUser, bool matched, DateTime createdAt
});




}
/// @nodoc
class __$InteractionRecordCopyWithImpl<$Res>
    implements _$InteractionRecordCopyWith<$Res> {
  __$InteractionRecordCopyWithImpl(this._self, this._then);

  final _InteractionRecord _self;
  final $Res Function(_InteractionRecord) _then;

/// Create a copy of InteractionRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromUser = freezed,Object? fromUserName = freezed,Object? fromUserUsername = freezed,Object? fromUserProfileImageUrl = freezed,Object? fromUserShareCode = freezed,Object? fromUserInstagramId = freezed,Object? fromUserSnapchatId = freezed,Object? toUser = null,Object? type = null,Object? metadata = freezed,Object? respondedByCurrentUser = null,Object? matched = null,Object? createdAt = null,}) {
  return _then(_InteractionRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromUser: freezed == fromUser ? _self.fromUser : fromUser // ignore: cast_nullable_to_non_nullable
as String?,fromUserName: freezed == fromUserName ? _self.fromUserName : fromUserName // ignore: cast_nullable_to_non_nullable
as String?,fromUserUsername: freezed == fromUserUsername ? _self.fromUserUsername : fromUserUsername // ignore: cast_nullable_to_non_nullable
as String?,fromUserProfileImageUrl: freezed == fromUserProfileImageUrl ? _self.fromUserProfileImageUrl : fromUserProfileImageUrl // ignore: cast_nullable_to_non_nullable
as String?,fromUserShareCode: freezed == fromUserShareCode ? _self.fromUserShareCode : fromUserShareCode // ignore: cast_nullable_to_non_nullable
as String?,fromUserInstagramId: freezed == fromUserInstagramId ? _self.fromUserInstagramId : fromUserInstagramId // ignore: cast_nullable_to_non_nullable
as String?,fromUserSnapchatId: freezed == fromUserSnapchatId ? _self.fromUserSnapchatId : fromUserSnapchatId // ignore: cast_nullable_to_non_nullable
as String?,toUser: null == toUser ? _self.toUser : toUser // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as InteractionType,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,respondedByCurrentUser: null == respondedByCurrentUser ? _self.respondedByCurrentUser : respondedByCurrentUser // ignore: cast_nullable_to_non_nullable
as bool,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

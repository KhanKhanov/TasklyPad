// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationEntry {

/// Растёт с каждой записью и не повторяется даже после «Очистить всё».
 int get id;/// Когда показано — Unix-миллисекунды UTC (часы приложения).
 int get atMs;/// Текст на языке интерфейса в момент показа.
 String get text;
/// Create a copy of NotificationEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationEntryCopyWith<NotificationEntry> get copyWith => _$NotificationEntryCopyWithImpl<NotificationEntry>(this as NotificationEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NotificationEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.atMs, _this.atMs) || other.atMs == _this.atMs)&&(identical(other.text, _this.text) || other.text == _this.text));
}


@override
int get hashCode {
  final _this = this as NotificationEntry;
  return Object.hash(runtimeType,_this.id,_this.atMs,_this.text);
}

@override
String toString() {
  final _this = this as NotificationEntry;
  return 'NotificationEntry(id: ${_this.id}, atMs: ${_this.atMs}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $NotificationEntryCopyWith<$Res>  {
  factory $NotificationEntryCopyWith(NotificationEntry value, $Res Function(NotificationEntry) _then) = _$NotificationEntryCopyWithImpl;
@useResult
$Res call({
 int id, int atMs, String text
});




}
/// @nodoc
class _$NotificationEntryCopyWithImpl<$Res>
    implements $NotificationEntryCopyWith<$Res> {
  _$NotificationEntryCopyWithImpl(this._self, this._then);

  final NotificationEntry _self;
  final $Res Function(NotificationEntry) _then;

/// Create a copy of NotificationEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? atMs = null,Object? text = null,}) {
  return _then(NotificationEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,atMs: null == atMs ? _self.atMs : atMs // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationEntry].
extension NotificationEntryPatterns on NotificationEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationEntry value)  $default,){
final _that = this;
switch (_that) {
case _NotificationEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationEntry value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int atMs,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationEntry() when $default != null:
return $default(_that.id,_that.atMs,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int atMs,  String text)  $default,) {final _that = this;
switch (_that) {
case _NotificationEntry():
return $default(_that.id,_that.atMs,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int atMs,  String text)?  $default,) {final _that = this;
switch (_that) {
case _NotificationEntry() when $default != null:
return $default(_that.id,_that.atMs,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationEntry implements NotificationEntry {
  const _NotificationEntry({required this.id, required this.atMs, required this.text});
  

/// Растёт с каждой записью и не повторяется даже после «Очистить всё».
@override final  int id;
/// Когда показано — Unix-миллисекунды UTC (часы приложения).
@override final  int atMs;
/// Текст на языке интерфейса в момент показа.
@override final  String text;

/// Create a copy of NotificationEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationEntryCopyWith<_NotificationEntry> get copyWith => __$NotificationEntryCopyWithImpl<_NotificationEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.atMs, atMs) || other.atMs == atMs)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,atMs,text);
}

@override
String toString() {
    return 'NotificationEntry(id: $id, atMs: $atMs, text: $text)';
}


}

/// @nodoc
abstract mixin class _$NotificationEntryCopyWith<$Res> implements $NotificationEntryCopyWith<$Res> {
  factory _$NotificationEntryCopyWith(_NotificationEntry value, $Res Function(_NotificationEntry) _then) = __$NotificationEntryCopyWithImpl;
@override @useResult
$Res call({
 int id, int atMs, String text
});




}
/// @nodoc
class __$NotificationEntryCopyWithImpl<$Res>
    implements _$NotificationEntryCopyWith<$Res> {
  __$NotificationEntryCopyWithImpl(this._self, this._then);

  final _NotificationEntry _self;
  final $Res Function(_NotificationEntry) _then;

/// Create a copy of NotificationEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? atMs = null,Object? text = null,}) {
  return _then(_NotificationEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,atMs: null == atMs ? _self.atMs : atMs // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$NotificationLog {

 int get nextId; int get seenId; List<NotificationEntry> get items;
/// Create a copy of NotificationLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationLogCopyWith<NotificationLog> get copyWith => _$NotificationLogCopyWithImpl<NotificationLog>(this as NotificationLog, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NotificationLog;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationLog&&(identical(other.nextId, _this.nextId) || other.nextId == _this.nextId)&&(identical(other.seenId, _this.seenId) || other.seenId == _this.seenId)&&const DeepCollectionEquality().equals(other.items, _this.items));
}


@override
int get hashCode {
  final _this = this as NotificationLog;
  return Object.hash(runtimeType,_this.nextId,_this.seenId,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as NotificationLog;
  return 'NotificationLog(nextId: ${_this.nextId}, seenId: ${_this.seenId}, items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $NotificationLogCopyWith<$Res>  {
  factory $NotificationLogCopyWith(NotificationLog value, $Res Function(NotificationLog) _then) = _$NotificationLogCopyWithImpl;
@useResult
$Res call({
 int nextId, int seenId, List<NotificationEntry> items
});




}
/// @nodoc
class _$NotificationLogCopyWithImpl<$Res>
    implements $NotificationLogCopyWith<$Res> {
  _$NotificationLogCopyWithImpl(this._self, this._then);

  final NotificationLog _self;
  final $Res Function(NotificationLog) _then;

/// Create a copy of NotificationLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nextId = null,Object? seenId = null,Object? items = null,}) {
  return _then(NotificationLog(
nextId: null == nextId ? _self.nextId : nextId // ignore: cast_nullable_to_non_nullable
as int,seenId: null == seenId ? _self.seenId : seenId // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<NotificationEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationLog].
extension NotificationLogPatterns on NotificationLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationLog value)  $default,){
final _that = this;
switch (_that) {
case _NotificationLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationLog value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int nextId,  int seenId,  List<NotificationEntry> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationLog() when $default != null:
return $default(_that.nextId,_that.seenId,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int nextId,  int seenId,  List<NotificationEntry> items)  $default,) {final _that = this;
switch (_that) {
case _NotificationLog():
return $default(_that.nextId,_that.seenId,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int nextId,  int seenId,  List<NotificationEntry> items)?  $default,) {final _that = this;
switch (_that) {
case _NotificationLog() when $default != null:
return $default(_that.nextId,_that.seenId,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationLog extends NotificationLog {
  const _NotificationLog({this.nextId = 1, this.seenId = 0,  List<NotificationEntry> items = const <NotificationEntry>[]}): _items = items,super._();
  

@override@JsonKey() final  int nextId;
@override@JsonKey() final  int seenId;
 final  List<NotificationEntry> _items;
@override@JsonKey() List<NotificationEntry> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of NotificationLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationLogCopyWith<_NotificationLog> get copyWith => __$NotificationLogCopyWithImpl<_NotificationLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationLog&&(identical(other.nextId, nextId) || other.nextId == nextId)&&(identical(other.seenId, seenId) || other.seenId == seenId)&&const DeepCollectionEquality().equals(other.items, _items));
}


@override
int get hashCode {
    return Object.hash(runtimeType,nextId,seenId,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'NotificationLog(nextId: $nextId, seenId: $seenId, items: $items)';
}


}

/// @nodoc
abstract mixin class _$NotificationLogCopyWith<$Res> implements $NotificationLogCopyWith<$Res> {
  factory _$NotificationLogCopyWith(_NotificationLog value, $Res Function(_NotificationLog) _then) = __$NotificationLogCopyWithImpl;
@override @useResult
$Res call({
 int nextId, int seenId, List<NotificationEntry> items
});




}
/// @nodoc
class __$NotificationLogCopyWithImpl<$Res>
    implements _$NotificationLogCopyWith<$Res> {
  __$NotificationLogCopyWithImpl(this._self, this._then);

  final _NotificationLog _self;
  final $Res Function(_NotificationLog) _then;

/// Create a copy of NotificationLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nextId = null,Object? seenId = null,Object? items = null,}) {
  return _then(_NotificationLog(
nextId: null == nextId ? _self.nextId : nextId // ignore: cast_nullable_to_non_nullable
as int,seenId: null == seenId ? _self.seenId : seenId // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<NotificationEntry>,
  ));
}


}

// dart format on

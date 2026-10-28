// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conflicts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConflictRef {

 String get id;/// Имя или название; `null` — этой сущности на устройстве нет.
 String? get title; bool get isInbox; bool get isDeleted;
/// Create a copy of ConflictRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConflictRefCopyWith<ConflictRef> get copyWith => _$ConflictRefCopyWithImpl<ConflictRef>(this as ConflictRef, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConflictRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConflictRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.isInbox, _this.isInbox) || other.isInbox == _this.isInbox)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted));
}


@override
int get hashCode {
  final _this = this as ConflictRef;
  return Object.hash(runtimeType,_this.id,_this.title,_this.isInbox,_this.isDeleted);
}

@override
String toString() {
  final _this = this as ConflictRef;
  return 'ConflictRef(id: ${_this.id}, title: ${_this.title}, isInbox: ${_this.isInbox}, isDeleted: ${_this.isDeleted})';
}


}

/// @nodoc
abstract mixin class $ConflictRefCopyWith<$Res>  {
  factory $ConflictRefCopyWith(ConflictRef value, $Res Function(ConflictRef) _then) = _$ConflictRefCopyWithImpl;
@useResult
$Res call({
 String id, String? title, bool isInbox, bool isDeleted
});




}
/// @nodoc
class _$ConflictRefCopyWithImpl<$Res>
    implements $ConflictRefCopyWith<$Res> {
  _$ConflictRefCopyWithImpl(this._self, this._then);

  final ConflictRef _self;
  final $Res Function(ConflictRef) _then;

/// Create a copy of ConflictRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = freezed,Object? isInbox = null,Object? isDeleted = null,}) {
  return _then(ConflictRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConflictRef].
extension ConflictRefPatterns on ConflictRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConflictRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConflictRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConflictRef value)  $default,){
final _that = this;
switch (_that) {
case _ConflictRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConflictRef value)?  $default,){
final _that = this;
switch (_that) {
case _ConflictRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? title,  bool isInbox,  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConflictRef() when $default != null:
return $default(_that.id,_that.title,_that.isInbox,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? title,  bool isInbox,  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _ConflictRef():
return $default(_that.id,_that.title,_that.isInbox,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? title,  bool isInbox,  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _ConflictRef() when $default != null:
return $default(_that.id,_that.title,_that.isInbox,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc


class _ConflictRef implements ConflictRef {
  const _ConflictRef({required this.id, this.title, this.isInbox = false, this.isDeleted = false});
  

@override final  String id;
/// Имя или название; `null` — этой сущности на устройстве нет.
@override final  String? title;
@override@JsonKey() final  bool isInbox;
@override@JsonKey() final  bool isDeleted;

/// Create a copy of ConflictRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConflictRefCopyWith<_ConflictRef> get copyWith => __$ConflictRefCopyWithImpl<_ConflictRef>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConflictRef&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.isInbox, isInbox) || other.isInbox == isInbox)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,isInbox,isDeleted);
}

@override
String toString() {
    return 'ConflictRef(id: $id, title: $title, isInbox: $isInbox, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$ConflictRefCopyWith<$Res> implements $ConflictRefCopyWith<$Res> {
  factory _$ConflictRefCopyWith(_ConflictRef value, $Res Function(_ConflictRef) _then) = __$ConflictRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String? title, bool isInbox, bool isDeleted
});




}
/// @nodoc
class __$ConflictRefCopyWithImpl<$Res>
    implements _$ConflictRefCopyWith<$Res> {
  __$ConflictRefCopyWithImpl(this._self, this._then);

  final _ConflictRef _self;
  final $Res Function(_ConflictRef) _then;

/// Create a copy of ConflictRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = freezed,Object? isInbox = null,Object? isDeleted = null,}) {
  return _then(_ConflictRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ConflictValue {

 ConflictField get field;/// Имя поля в журнале — подпись незнакомого поля.
 String get key; Object? get value;
/// Create a copy of ConflictValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConflictValueCopyWith<ConflictValue> get copyWith => _$ConflictValueCopyWithImpl<ConflictValue>(this as ConflictValue, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConflictValue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConflictValue&&(identical(other.field, _this.field) || other.field == _this.field)&&(identical(other.key, _this.key) || other.key == _this.key)&&const DeepCollectionEquality().equals(other.value, _this.value));
}


@override
int get hashCode {
  final _this = this as ConflictValue;
  return Object.hash(runtimeType,_this.field,_this.key,const DeepCollectionEquality().hash(_this.value));
}

@override
String toString() {
  final _this = this as ConflictValue;
  return 'ConflictValue(field: ${_this.field}, key: ${_this.key}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $ConflictValueCopyWith<$Res>  {
  factory $ConflictValueCopyWith(ConflictValue value, $Res Function(ConflictValue) _then) = _$ConflictValueCopyWithImpl;
@useResult
$Res call({
 ConflictField field, String key, Object? value
});




}
/// @nodoc
class _$ConflictValueCopyWithImpl<$Res>
    implements $ConflictValueCopyWith<$Res> {
  _$ConflictValueCopyWithImpl(this._self, this._then);

  final ConflictValue _self;
  final $Res Function(ConflictValue) _then;

/// Create a copy of ConflictValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field = null,Object? key = null,Object? value = freezed,}) {
  return _then(ConflictValue(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as ConflictField,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [ConflictValue].
extension ConflictValuePatterns on ConflictValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConflictValue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConflictValue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConflictValue value)  $default,){
final _that = this;
switch (_that) {
case _ConflictValue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConflictValue value)?  $default,){
final _that = this;
switch (_that) {
case _ConflictValue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConflictField field,  String key,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConflictValue() when $default != null:
return $default(_that.field,_that.key,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConflictField field,  String key,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _ConflictValue():
return $default(_that.field,_that.key,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConflictField field,  String key,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _ConflictValue() when $default != null:
return $default(_that.field,_that.key,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _ConflictValue implements ConflictValue {
  const _ConflictValue({required this.field, required this.key, this.value});
  

@override final  ConflictField field;
/// Имя поля в журнале — подпись незнакомого поля.
@override final  String key;
@override final  Object? value;

/// Create a copy of ConflictValue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConflictValueCopyWith<_ConflictValue> get copyWith => __$ConflictValueCopyWithImpl<_ConflictValue>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConflictValue&&(identical(other.field, field) || other.field == field)&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field,key,const DeepCollectionEquality().hash(value));
}

@override
String toString() {
    return 'ConflictValue(field: $field, key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class _$ConflictValueCopyWith<$Res> implements $ConflictValueCopyWith<$Res> {
  factory _$ConflictValueCopyWith(_ConflictValue value, $Res Function(_ConflictValue) _then) = __$ConflictValueCopyWithImpl;
@override @useResult
$Res call({
 ConflictField field, String key, Object? value
});




}
/// @nodoc
class __$ConflictValueCopyWithImpl<$Res>
    implements _$ConflictValueCopyWith<$Res> {
  __$ConflictValueCopyWithImpl(this._self, this._then);

  final _ConflictValue _self;
  final $Res Function(_ConflictValue) _then;

/// Create a copy of ConflictValue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field = null,Object? key = null,Object? value = freezed,}) {
  return _then(_ConflictValue(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as ConflictField,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}

/// @nodoc
mixin _$ConflictSide {

 String get nodeId;/// Правка этого устройства — или его прежнего id (база скопирована).
 bool get isThisDevice; bool get isFormerThisDevice;/// Время правки по часам её устройства, UTC.
 DateTime get at;/// Сторона удалила сущность (у метки задачи — сняла метку).
 bool get deletes;/// Что показать.
 List<ConflictValue> get values;/// Что записать при выборе этой стороны: поле журнала → значение.
 Map<String, Object?> get fields;/// Значения этой стороны действуют сейчас.
 bool get isCurrent;
/// Create a copy of ConflictSide
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConflictSideCopyWith<ConflictSide> get copyWith => _$ConflictSideCopyWithImpl<ConflictSide>(this as ConflictSide, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConflictSide;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConflictSide&&(identical(other.nodeId, _this.nodeId) || other.nodeId == _this.nodeId)&&(identical(other.isThisDevice, _this.isThisDevice) || other.isThisDevice == _this.isThisDevice)&&(identical(other.isFormerThisDevice, _this.isFormerThisDevice) || other.isFormerThisDevice == _this.isFormerThisDevice)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.deletes, _this.deletes) || other.deletes == _this.deletes)&&const DeepCollectionEquality().equals(other.values, _this.values)&&const DeepCollectionEquality().equals(other.fields, _this.fields)&&(identical(other.isCurrent, _this.isCurrent) || other.isCurrent == _this.isCurrent));
}


@override
int get hashCode {
  final _this = this as ConflictSide;
  return Object.hash(runtimeType,_this.nodeId,_this.isThisDevice,_this.isFormerThisDevice,_this.at,_this.deletes,const DeepCollectionEquality().hash(_this.values),const DeepCollectionEquality().hash(_this.fields),_this.isCurrent);
}

@override
String toString() {
  final _this = this as ConflictSide;
  return 'ConflictSide(nodeId: ${_this.nodeId}, isThisDevice: ${_this.isThisDevice}, isFormerThisDevice: ${_this.isFormerThisDevice}, at: ${_this.at}, deletes: ${_this.deletes}, values: ${_this.values}, fields: ${_this.fields}, isCurrent: ${_this.isCurrent})';
}


}

/// @nodoc
abstract mixin class $ConflictSideCopyWith<$Res>  {
  factory $ConflictSideCopyWith(ConflictSide value, $Res Function(ConflictSide) _then) = _$ConflictSideCopyWithImpl;
@useResult
$Res call({
 String nodeId, bool isThisDevice, bool isFormerThisDevice, DateTime at, bool deletes, List<ConflictValue> values, Map<String, Object?> fields, bool isCurrent
});




}
/// @nodoc
class _$ConflictSideCopyWithImpl<$Res>
    implements $ConflictSideCopyWith<$Res> {
  _$ConflictSideCopyWithImpl(this._self, this._then);

  final ConflictSide _self;
  final $Res Function(ConflictSide) _then;

/// Create a copy of ConflictSide
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodeId = null,Object? isThisDevice = null,Object? isFormerThisDevice = null,Object? at = null,Object? deletes = null,Object? values = null,Object? fields = null,Object? isCurrent = null,}) {
  return _then(ConflictSide(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,isThisDevice: null == isThisDevice ? _self.isThisDevice : isThisDevice // ignore: cast_nullable_to_non_nullable
as bool,isFormerThisDevice: null == isFormerThisDevice ? _self.isFormerThisDevice : isFormerThisDevice // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,deletes: null == deletes ? _self.deletes : deletes // ignore: cast_nullable_to_non_nullable
as bool,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<ConflictValue>,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConflictSide].
extension ConflictSidePatterns on ConflictSide {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConflictSide value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConflictSide() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConflictSide value)  $default,){
final _that = this;
switch (_that) {
case _ConflictSide():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConflictSide value)?  $default,){
final _that = this;
switch (_that) {
case _ConflictSide() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nodeId,  bool isThisDevice,  bool isFormerThisDevice,  DateTime at,  bool deletes,  List<ConflictValue> values,  Map<String, Object?> fields,  bool isCurrent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConflictSide() when $default != null:
return $default(_that.nodeId,_that.isThisDevice,_that.isFormerThisDevice,_that.at,_that.deletes,_that.values,_that.fields,_that.isCurrent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nodeId,  bool isThisDevice,  bool isFormerThisDevice,  DateTime at,  bool deletes,  List<ConflictValue> values,  Map<String, Object?> fields,  bool isCurrent)  $default,) {final _that = this;
switch (_that) {
case _ConflictSide():
return $default(_that.nodeId,_that.isThisDevice,_that.isFormerThisDevice,_that.at,_that.deletes,_that.values,_that.fields,_that.isCurrent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nodeId,  bool isThisDevice,  bool isFormerThisDevice,  DateTime at,  bool deletes,  List<ConflictValue> values,  Map<String, Object?> fields,  bool isCurrent)?  $default,) {final _that = this;
switch (_that) {
case _ConflictSide() when $default != null:
return $default(_that.nodeId,_that.isThisDevice,_that.isFormerThisDevice,_that.at,_that.deletes,_that.values,_that.fields,_that.isCurrent);case _:
  return null;

}
}

}

/// @nodoc


class _ConflictSide implements ConflictSide {
  const _ConflictSide({required this.nodeId, this.isThisDevice = false, this.isFormerThisDevice = false, required this.at, required this.deletes, required  List<ConflictValue> values, required  Map<String, Object?> fields, required this.isCurrent}): _values = values,_fields = fields;
  

@override final  String nodeId;
/// Правка этого устройства — или его прежнего id (база скопирована).
@override@JsonKey() final  bool isThisDevice;
@override@JsonKey() final  bool isFormerThisDevice;
/// Время правки по часам её устройства, UTC.
@override final  DateTime at;
/// Сторона удалила сущность (у метки задачи — сняла метку).
@override final  bool deletes;
/// Что показать.
 final  List<ConflictValue> _values;
/// Что показать.
@override List<ConflictValue> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}

/// Что записать при выборе этой стороны: поле журнала → значение.
 final  Map<String, Object?> _fields;
/// Что записать при выборе этой стороны: поле журнала → значение.
@override Map<String, Object?> get fields {
  if (_fields is EqualUnmodifiableMapView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fields);
}

/// Значения этой стороны действуют сейчас.
@override final  bool isCurrent;

/// Create a copy of ConflictSide
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConflictSideCopyWith<_ConflictSide> get copyWith => __$ConflictSideCopyWithImpl<_ConflictSide>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConflictSide&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.isThisDevice, isThisDevice) || other.isThisDevice == isThisDevice)&&(identical(other.isFormerThisDevice, isFormerThisDevice) || other.isFormerThisDevice == isFormerThisDevice)&&(identical(other.at, at) || other.at == at)&&(identical(other.deletes, deletes) || other.deletes == deletes)&&const DeepCollectionEquality().equals(other.values, _values)&&const DeepCollectionEquality().equals(other.fields, _fields)&&(identical(other.isCurrent, isCurrent) || other.isCurrent == isCurrent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,nodeId,isThisDevice,isFormerThisDevice,at,deletes,const DeepCollectionEquality().hash(_values),const DeepCollectionEquality().hash(_fields),isCurrent);
}

@override
String toString() {
    return 'ConflictSide(nodeId: $nodeId, isThisDevice: $isThisDevice, isFormerThisDevice: $isFormerThisDevice, at: $at, deletes: $deletes, values: $values, fields: $fields, isCurrent: $isCurrent)';
}


}

/// @nodoc
abstract mixin class _$ConflictSideCopyWith<$Res> implements $ConflictSideCopyWith<$Res> {
  factory _$ConflictSideCopyWith(_ConflictSide value, $Res Function(_ConflictSide) _then) = __$ConflictSideCopyWithImpl;
@override @useResult
$Res call({
 String nodeId, bool isThisDevice, bool isFormerThisDevice, DateTime at, bool deletes, List<ConflictValue> values, Map<String, Object?> fields, bool isCurrent
});




}
/// @nodoc
class __$ConflictSideCopyWithImpl<$Res>
    implements _$ConflictSideCopyWith<$Res> {
  __$ConflictSideCopyWithImpl(this._self, this._then);

  final _ConflictSide _self;
  final $Res Function(_ConflictSide) _then;

/// Create a copy of ConflictSide
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodeId = null,Object? isThisDevice = null,Object? isFormerThisDevice = null,Object? at = null,Object? deletes = null,Object? values = null,Object? fields = null,Object? isCurrent = null,}) {
  return _then(_ConflictSide(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,isThisDevice: null == isThisDevice ? _self.isThisDevice : isThisDevice // ignore: cast_nullable_to_non_nullable
as bool,isFormerThisDevice: null == isFormerThisDevice ? _self.isFormerThisDevice : isFormerThisDevice // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,deletes: null == deletes ? _self.deletes : deletes // ignore: cast_nullable_to_non_nullable
as bool,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<ConflictValue>,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ConflictCard {

 ConflictEntity get entity; String get entityId;/// Название задачи или имя проекта, раздела, метки; `null` — пусто.
 String? get title; bool get isInbox;/// У метки задачи — название задачи ([title] — имя метки).
 String? get ownerTitle; bool get isDelete; List<String> get conflictIds;/// Более ранняя правка — проигравшая, пока пользователь не выбрал.
 ConflictSide get older; ConflictSide get newer;/// Действующие значения, если ни одна сторона не действует целиком
/// (поле правили после конфликта), иначе пусто.
 List<ConflictValue> get current;
/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConflictCardCopyWith<ConflictCard> get copyWith => _$ConflictCardCopyWithImpl<ConflictCard>(this as ConflictCard, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConflictCard;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConflictCard&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&(identical(other.entityId, _this.entityId) || other.entityId == _this.entityId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.isInbox, _this.isInbox) || other.isInbox == _this.isInbox)&&(identical(other.ownerTitle, _this.ownerTitle) || other.ownerTitle == _this.ownerTitle)&&(identical(other.isDelete, _this.isDelete) || other.isDelete == _this.isDelete)&&const DeepCollectionEquality().equals(other.conflictIds, _this.conflictIds)&&(identical(other.older, _this.older) || other.older == _this.older)&&(identical(other.newer, _this.newer) || other.newer == _this.newer)&&const DeepCollectionEquality().equals(other.current, _this.current));
}


@override
int get hashCode {
  final _this = this as ConflictCard;
  return Object.hash(runtimeType,_this.entity,_this.entityId,_this.title,_this.isInbox,_this.ownerTitle,_this.isDelete,const DeepCollectionEquality().hash(_this.conflictIds),_this.older,_this.newer,const DeepCollectionEquality().hash(_this.current));
}

@override
String toString() {
  final _this = this as ConflictCard;
  return 'ConflictCard(entity: ${_this.entity}, entityId: ${_this.entityId}, title: ${_this.title}, isInbox: ${_this.isInbox}, ownerTitle: ${_this.ownerTitle}, isDelete: ${_this.isDelete}, conflictIds: ${_this.conflictIds}, older: ${_this.older}, newer: ${_this.newer}, current: ${_this.current})';
}


}

/// @nodoc
abstract mixin class $ConflictCardCopyWith<$Res>  {
  factory $ConflictCardCopyWith(ConflictCard value, $Res Function(ConflictCard) _then) = _$ConflictCardCopyWithImpl;
@useResult
$Res call({
 ConflictEntity entity, String entityId, String? title, bool isInbox, String? ownerTitle, bool isDelete, List<String> conflictIds, ConflictSide older, ConflictSide newer, List<ConflictValue> current
});


$ConflictSideCopyWith<$Res> get older;$ConflictSideCopyWith<$Res> get newer;

}
/// @nodoc
class _$ConflictCardCopyWithImpl<$Res>
    implements $ConflictCardCopyWith<$Res> {
  _$ConflictCardCopyWithImpl(this._self, this._then);

  final ConflictCard _self;
  final $Res Function(ConflictCard) _then;

/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entity = null,Object? entityId = null,Object? title = freezed,Object? isInbox = null,Object? ownerTitle = freezed,Object? isDelete = null,Object? conflictIds = null,Object? older = null,Object? newer = null,Object? current = null,}) {
  return _then(ConflictCard(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as ConflictEntity,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,ownerTitle: freezed == ownerTitle ? _self.ownerTitle : ownerTitle // ignore: cast_nullable_to_non_nullable
as String?,isDelete: null == isDelete ? _self.isDelete : isDelete // ignore: cast_nullable_to_non_nullable
as bool,conflictIds: null == conflictIds ? _self.conflictIds : conflictIds // ignore: cast_nullable_to_non_nullable
as List<String>,older: null == older ? _self.older : older // ignore: cast_nullable_to_non_nullable
as ConflictSide,newer: null == newer ? _self.newer : newer // ignore: cast_nullable_to_non_nullable
as ConflictSide,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as List<ConflictValue>,
  ));
}
/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConflictSideCopyWith<$Res> get older {
  
  return $ConflictSideCopyWith<$Res>(_self.older, (value) {
    return _then(_self.copyWith(older: value));
  });
}/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConflictSideCopyWith<$Res> get newer {
  
  return $ConflictSideCopyWith<$Res>(_self.newer, (value) {
    return _then(_self.copyWith(newer: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConflictCard].
extension ConflictCardPatterns on ConflictCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConflictCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConflictCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConflictCard value)  $default,){
final _that = this;
switch (_that) {
case _ConflictCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConflictCard value)?  $default,){
final _that = this;
switch (_that) {
case _ConflictCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConflictEntity entity,  String entityId,  String? title,  bool isInbox,  String? ownerTitle,  bool isDelete,  List<String> conflictIds,  ConflictSide older,  ConflictSide newer,  List<ConflictValue> current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConflictCard() when $default != null:
return $default(_that.entity,_that.entityId,_that.title,_that.isInbox,_that.ownerTitle,_that.isDelete,_that.conflictIds,_that.older,_that.newer,_that.current);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConflictEntity entity,  String entityId,  String? title,  bool isInbox,  String? ownerTitle,  bool isDelete,  List<String> conflictIds,  ConflictSide older,  ConflictSide newer,  List<ConflictValue> current)  $default,) {final _that = this;
switch (_that) {
case _ConflictCard():
return $default(_that.entity,_that.entityId,_that.title,_that.isInbox,_that.ownerTitle,_that.isDelete,_that.conflictIds,_that.older,_that.newer,_that.current);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConflictEntity entity,  String entityId,  String? title,  bool isInbox,  String? ownerTitle,  bool isDelete,  List<String> conflictIds,  ConflictSide older,  ConflictSide newer,  List<ConflictValue> current)?  $default,) {final _that = this;
switch (_that) {
case _ConflictCard() when $default != null:
return $default(_that.entity,_that.entityId,_that.title,_that.isInbox,_that.ownerTitle,_that.isDelete,_that.conflictIds,_that.older,_that.newer,_that.current);case _:
  return null;

}
}

}

/// @nodoc


class _ConflictCard extends ConflictCard {
  const _ConflictCard({required this.entity, required this.entityId, this.title, this.isInbox = false, this.ownerTitle, required this.isDelete, required  List<String> conflictIds, required this.older, required this.newer,  List<ConflictValue> current = const <ConflictValue>[]}): _conflictIds = conflictIds,_current = current,super._();
  

@override final  ConflictEntity entity;
@override final  String entityId;
/// Название задачи или имя проекта, раздела, метки; `null` — пусто.
@override final  String? title;
@override@JsonKey() final  bool isInbox;
/// У метки задачи — название задачи ([title] — имя метки).
@override final  String? ownerTitle;
@override final  bool isDelete;
 final  List<String> _conflictIds;
@override List<String> get conflictIds {
  if (_conflictIds is EqualUnmodifiableListView) return _conflictIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_conflictIds);
}

/// Более ранняя правка — проигравшая, пока пользователь не выбрал.
@override final  ConflictSide older;
@override final  ConflictSide newer;
/// Действующие значения, если ни одна сторона не действует целиком
/// (поле правили после конфликта), иначе пусто.
 final  List<ConflictValue> _current;
/// Действующие значения, если ни одна сторона не действует целиком
/// (поле правили после конфликта), иначе пусто.
@override@JsonKey() List<ConflictValue> get current {
  if (_current is EqualUnmodifiableListView) return _current;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_current);
}


/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConflictCardCopyWith<_ConflictCard> get copyWith => __$ConflictCardCopyWithImpl<_ConflictCard>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConflictCard&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.title, title) || other.title == title)&&(identical(other.isInbox, isInbox) || other.isInbox == isInbox)&&(identical(other.ownerTitle, ownerTitle) || other.ownerTitle == ownerTitle)&&(identical(other.isDelete, isDelete) || other.isDelete == isDelete)&&const DeepCollectionEquality().equals(other.conflictIds, _conflictIds)&&(identical(other.older, older) || other.older == older)&&(identical(other.newer, newer) || other.newer == newer)&&const DeepCollectionEquality().equals(other.current, _current));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entity,entityId,title,isInbox,ownerTitle,isDelete,const DeepCollectionEquality().hash(_conflictIds),older,newer,const DeepCollectionEquality().hash(_current));
}

@override
String toString() {
    return 'ConflictCard(entity: $entity, entityId: $entityId, title: $title, isInbox: $isInbox, ownerTitle: $ownerTitle, isDelete: $isDelete, conflictIds: $conflictIds, older: $older, newer: $newer, current: $current)';
}


}

/// @nodoc
abstract mixin class _$ConflictCardCopyWith<$Res> implements $ConflictCardCopyWith<$Res> {
  factory _$ConflictCardCopyWith(_ConflictCard value, $Res Function(_ConflictCard) _then) = __$ConflictCardCopyWithImpl;
@override @useResult
$Res call({
 ConflictEntity entity, String entityId, String? title, bool isInbox, String? ownerTitle, bool isDelete, List<String> conflictIds, ConflictSide older, ConflictSide newer, List<ConflictValue> current
});


@override $ConflictSideCopyWith<$Res> get older;@override $ConflictSideCopyWith<$Res> get newer;

}
/// @nodoc
class __$ConflictCardCopyWithImpl<$Res>
    implements _$ConflictCardCopyWith<$Res> {
  __$ConflictCardCopyWithImpl(this._self, this._then);

  final _ConflictCard _self;
  final $Res Function(_ConflictCard) _then;

/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? entityId = null,Object? title = freezed,Object? isInbox = null,Object? ownerTitle = freezed,Object? isDelete = null,Object? conflictIds = null,Object? older = null,Object? newer = null,Object? current = null,}) {
  return _then(_ConflictCard(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as ConflictEntity,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,ownerTitle: freezed == ownerTitle ? _self.ownerTitle : ownerTitle // ignore: cast_nullable_to_non_nullable
as String?,isDelete: null == isDelete ? _self.isDelete : isDelete // ignore: cast_nullable_to_non_nullable
as bool,conflictIds: null == conflictIds ? _self._conflictIds : conflictIds // ignore: cast_nullable_to_non_nullable
as List<String>,older: null == older ? _self.older : older // ignore: cast_nullable_to_non_nullable
as ConflictSide,newer: null == newer ? _self.newer : newer // ignore: cast_nullable_to_non_nullable
as ConflictSide,current: null == current ? _self._current : current // ignore: cast_nullable_to_non_nullable
as List<ConflictValue>,
  ));
}

/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConflictSideCopyWith<$Res> get older {
  
  return $ConflictSideCopyWith<$Res>(_self.older, (value) {
    return _then(_self.copyWith(older: value));
  });
}/// Create a copy of ConflictCard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConflictSideCopyWith<$Res> get newer {
  
  return $ConflictSideCopyWith<$Res>(_self.newer, (value) {
    return _then(_self.copyWith(newer: value));
  });
}
}

// dart format on

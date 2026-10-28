// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThemeChoice {

 String get themeId; ThemeAppearance get appearance;
/// Create a copy of ThemeChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeChoiceCopyWith<ThemeChoice> get copyWith => _$ThemeChoiceCopyWithImpl<ThemeChoice>(this as ThemeChoice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ThemeChoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeChoice&&(identical(other.themeId, _this.themeId) || other.themeId == _this.themeId)&&(identical(other.appearance, _this.appearance) || other.appearance == _this.appearance));
}


@override
int get hashCode {
  final _this = this as ThemeChoice;
  return Object.hash(runtimeType,_this.themeId,_this.appearance);
}

@override
String toString() {
  final _this = this as ThemeChoice;
  return 'ThemeChoice(themeId: ${_this.themeId}, appearance: ${_this.appearance})';
}


}

/// @nodoc
abstract mixin class $ThemeChoiceCopyWith<$Res>  {
  factory $ThemeChoiceCopyWith(ThemeChoice value, $Res Function(ThemeChoice) _then) = _$ThemeChoiceCopyWithImpl;
@useResult
$Res call({
 String themeId, ThemeAppearance appearance
});




}
/// @nodoc
class _$ThemeChoiceCopyWithImpl<$Res>
    implements $ThemeChoiceCopyWith<$Res> {
  _$ThemeChoiceCopyWithImpl(this._self, this._then);

  final ThemeChoice _self;
  final $Res Function(ThemeChoice) _then;

/// Create a copy of ThemeChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeId = null,Object? appearance = null,}) {
  return _then(ThemeChoice(
themeId: null == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeChoice].
extension ThemeChoicePatterns on ThemeChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeChoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeChoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeChoice value)  $default,){
final _that = this;
switch (_that) {
case _ThemeChoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeChoice value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeChoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String themeId,  ThemeAppearance appearance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeChoice() when $default != null:
return $default(_that.themeId,_that.appearance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String themeId,  ThemeAppearance appearance)  $default,) {final _that = this;
switch (_that) {
case _ThemeChoice():
return $default(_that.themeId,_that.appearance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String themeId,  ThemeAppearance appearance)?  $default,) {final _that = this;
switch (_that) {
case _ThemeChoice() when $default != null:
return $default(_that.themeId,_that.appearance);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeChoice implements ThemeChoice {
  const _ThemeChoice({required this.themeId, required this.appearance});
  

@override final  String themeId;
@override final  ThemeAppearance appearance;

/// Create a copy of ThemeChoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeChoiceCopyWith<_ThemeChoice> get copyWith => __$ThemeChoiceCopyWithImpl<_ThemeChoice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeChoice&&(identical(other.themeId, themeId) || other.themeId == themeId)&&(identical(other.appearance, appearance) || other.appearance == appearance));
}


@override
int get hashCode {
    return Object.hash(runtimeType,themeId,appearance);
}

@override
String toString() {
    return 'ThemeChoice(themeId: $themeId, appearance: $appearance)';
}


}

/// @nodoc
abstract mixin class _$ThemeChoiceCopyWith<$Res> implements $ThemeChoiceCopyWith<$Res> {
  factory _$ThemeChoiceCopyWith(_ThemeChoice value, $Res Function(_ThemeChoice) _then) = __$ThemeChoiceCopyWithImpl;
@override @useResult
$Res call({
 String themeId, ThemeAppearance appearance
});




}
/// @nodoc
class __$ThemeChoiceCopyWithImpl<$Res>
    implements _$ThemeChoiceCopyWith<$Res> {
  __$ThemeChoiceCopyWithImpl(this._self, this._then);

  final _ThemeChoice _self;
  final $Res Function(_ThemeChoice) _then;

/// Create a copy of ThemeChoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeId = null,Object? appearance = null,}) {
  return _then(_ThemeChoice(
themeId: null == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance,
  ));
}


}

/// @nodoc
mixin _$ThemeSettings {

/// «Синхронизировать тему» на этом устройстве.
 bool get syncTheme;/// Общая тема — поля сущности `settings`; `null` — поля нет.
 String? get sharedThemeId; ThemeAppearance? get sharedAppearance;/// Тема устройства из `local_meta`; `null` — не выбиралась.
 String? get localThemeId; ThemeAppearance? get localAppearance;
/// Create a copy of ThemeSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeSettingsCopyWith<ThemeSettings> get copyWith => _$ThemeSettingsCopyWithImpl<ThemeSettings>(this as ThemeSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ThemeSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeSettings&&(identical(other.syncTheme, _this.syncTheme) || other.syncTheme == _this.syncTheme)&&(identical(other.sharedThemeId, _this.sharedThemeId) || other.sharedThemeId == _this.sharedThemeId)&&(identical(other.sharedAppearance, _this.sharedAppearance) || other.sharedAppearance == _this.sharedAppearance)&&(identical(other.localThemeId, _this.localThemeId) || other.localThemeId == _this.localThemeId)&&(identical(other.localAppearance, _this.localAppearance) || other.localAppearance == _this.localAppearance));
}


@override
int get hashCode {
  final _this = this as ThemeSettings;
  return Object.hash(runtimeType,_this.syncTheme,_this.sharedThemeId,_this.sharedAppearance,_this.localThemeId,_this.localAppearance);
}

@override
String toString() {
  final _this = this as ThemeSettings;
  return 'ThemeSettings(syncTheme: ${_this.syncTheme}, sharedThemeId: ${_this.sharedThemeId}, sharedAppearance: ${_this.sharedAppearance}, localThemeId: ${_this.localThemeId}, localAppearance: ${_this.localAppearance})';
}


}

/// @nodoc
abstract mixin class $ThemeSettingsCopyWith<$Res>  {
  factory $ThemeSettingsCopyWith(ThemeSettings value, $Res Function(ThemeSettings) _then) = _$ThemeSettingsCopyWithImpl;
@useResult
$Res call({
 bool syncTheme, String? sharedThemeId, ThemeAppearance? sharedAppearance, String? localThemeId, ThemeAppearance? localAppearance
});




}
/// @nodoc
class _$ThemeSettingsCopyWithImpl<$Res>
    implements $ThemeSettingsCopyWith<$Res> {
  _$ThemeSettingsCopyWithImpl(this._self, this._then);

  final ThemeSettings _self;
  final $Res Function(ThemeSettings) _then;

/// Create a copy of ThemeSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? syncTheme = null,Object? sharedThemeId = freezed,Object? sharedAppearance = freezed,Object? localThemeId = freezed,Object? localAppearance = freezed,}) {
  return _then(ThemeSettings(
syncTheme: null == syncTheme ? _self.syncTheme : syncTheme // ignore: cast_nullable_to_non_nullable
as bool,sharedThemeId: freezed == sharedThemeId ? _self.sharedThemeId : sharedThemeId // ignore: cast_nullable_to_non_nullable
as String?,sharedAppearance: freezed == sharedAppearance ? _self.sharedAppearance : sharedAppearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance?,localThemeId: freezed == localThemeId ? _self.localThemeId : localThemeId // ignore: cast_nullable_to_non_nullable
as String?,localAppearance: freezed == localAppearance ? _self.localAppearance : localAppearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance?,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeSettings].
extension ThemeSettingsPatterns on ThemeSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeSettings value)  $default,){
final _that = this;
switch (_that) {
case _ThemeSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool syncTheme,  String? sharedThemeId,  ThemeAppearance? sharedAppearance,  String? localThemeId,  ThemeAppearance? localAppearance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeSettings() when $default != null:
return $default(_that.syncTheme,_that.sharedThemeId,_that.sharedAppearance,_that.localThemeId,_that.localAppearance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool syncTheme,  String? sharedThemeId,  ThemeAppearance? sharedAppearance,  String? localThemeId,  ThemeAppearance? localAppearance)  $default,) {final _that = this;
switch (_that) {
case _ThemeSettings():
return $default(_that.syncTheme,_that.sharedThemeId,_that.sharedAppearance,_that.localThemeId,_that.localAppearance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool syncTheme,  String? sharedThemeId,  ThemeAppearance? sharedAppearance,  String? localThemeId,  ThemeAppearance? localAppearance)?  $default,) {final _that = this;
switch (_that) {
case _ThemeSettings() when $default != null:
return $default(_that.syncTheme,_that.sharedThemeId,_that.sharedAppearance,_that.localThemeId,_that.localAppearance);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeSettings extends ThemeSettings {
  const _ThemeSettings({this.syncTheme = true, this.sharedThemeId, this.sharedAppearance, this.localThemeId, this.localAppearance}): super._();
  

/// «Синхронизировать тему» на этом устройстве.
@override@JsonKey() final  bool syncTheme;
/// Общая тема — поля сущности `settings`; `null` — поля нет.
@override final  String? sharedThemeId;
@override final  ThemeAppearance? sharedAppearance;
/// Тема устройства из `local_meta`; `null` — не выбиралась.
@override final  String? localThemeId;
@override final  ThemeAppearance? localAppearance;

/// Create a copy of ThemeSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeSettingsCopyWith<_ThemeSettings> get copyWith => __$ThemeSettingsCopyWithImpl<_ThemeSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeSettings&&(identical(other.syncTheme, syncTheme) || other.syncTheme == syncTheme)&&(identical(other.sharedThemeId, sharedThemeId) || other.sharedThemeId == sharedThemeId)&&(identical(other.sharedAppearance, sharedAppearance) || other.sharedAppearance == sharedAppearance)&&(identical(other.localThemeId, localThemeId) || other.localThemeId == localThemeId)&&(identical(other.localAppearance, localAppearance) || other.localAppearance == localAppearance));
}


@override
int get hashCode {
    return Object.hash(runtimeType,syncTheme,sharedThemeId,sharedAppearance,localThemeId,localAppearance);
}

@override
String toString() {
    return 'ThemeSettings(syncTheme: $syncTheme, sharedThemeId: $sharedThemeId, sharedAppearance: $sharedAppearance, localThemeId: $localThemeId, localAppearance: $localAppearance)';
}


}

/// @nodoc
abstract mixin class _$ThemeSettingsCopyWith<$Res> implements $ThemeSettingsCopyWith<$Res> {
  factory _$ThemeSettingsCopyWith(_ThemeSettings value, $Res Function(_ThemeSettings) _then) = __$ThemeSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool syncTheme, String? sharedThemeId, ThemeAppearance? sharedAppearance, String? localThemeId, ThemeAppearance? localAppearance
});




}
/// @nodoc
class __$ThemeSettingsCopyWithImpl<$Res>
    implements _$ThemeSettingsCopyWith<$Res> {
  __$ThemeSettingsCopyWithImpl(this._self, this._then);

  final _ThemeSettings _self;
  final $Res Function(_ThemeSettings) _then;

/// Create a copy of ThemeSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? syncTheme = null,Object? sharedThemeId = freezed,Object? sharedAppearance = freezed,Object? localThemeId = freezed,Object? localAppearance = freezed,}) {
  return _then(_ThemeSettings(
syncTheme: null == syncTheme ? _self.syncTheme : syncTheme // ignore: cast_nullable_to_non_nullable
as bool,sharedThemeId: freezed == sharedThemeId ? _self.sharedThemeId : sharedThemeId // ignore: cast_nullable_to_non_nullable
as String?,sharedAppearance: freezed == sharedAppearance ? _self.sharedAppearance : sharedAppearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance?,localThemeId: freezed == localThemeId ? _self.localThemeId : localThemeId // ignore: cast_nullable_to_non_nullable
as String?,localAppearance: freezed == localAppearance ? _self.localAppearance : localAppearance // ignore: cast_nullable_to_non_nullable
as ThemeAppearance?,
  ));
}


}

// dart format on

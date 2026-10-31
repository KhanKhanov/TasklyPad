// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Project {

 String get id; String get name;/// Имя цвета палитры Todoist (`berry_red` … `taupe`).
 String get color; String? get parentId; String get orderKey; bool get isFavorite; bool get isArchived; bool get isInbox;/// `list`, `board` или `calendar`; незнакомое значение — как `list`.
 String get viewStyle; bool get isCollapsed;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.parentId, _this.parentId) || other.parentId == _this.parentId)&&(identical(other.orderKey, _this.orderKey) || other.orderKey == _this.orderKey)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&(identical(other.isArchived, _this.isArchived) || other.isArchived == _this.isArchived)&&(identical(other.isInbox, _this.isInbox) || other.isInbox == _this.isInbox)&&(identical(other.viewStyle, _this.viewStyle) || other.viewStyle == _this.viewStyle)&&(identical(other.isCollapsed, _this.isCollapsed) || other.isCollapsed == _this.isCollapsed));
}


@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.name,_this.color,_this.parentId,_this.orderKey,_this.isFavorite,_this.isArchived,_this.isInbox,_this.viewStyle,_this.isCollapsed);
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, name: ${_this.name}, color: ${_this.color}, parentId: ${_this.parentId}, orderKey: ${_this.orderKey}, isFavorite: ${_this.isFavorite}, isArchived: ${_this.isArchived}, isInbox: ${_this.isInbox}, viewStyle: ${_this.viewStyle}, isCollapsed: ${_this.isCollapsed})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, String color, String? parentId, String orderKey, bool isFavorite, bool isArchived, bool isInbox, String viewStyle, bool isCollapsed
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? parentId = freezed,Object? orderKey = null,Object? isFavorite = null,Object? isArchived = null,Object? isInbox = null,Object? viewStyle = null,Object? isCollapsed = null,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,viewStyle: null == viewStyle ? _self.viewStyle : viewStyle // ignore: cast_nullable_to_non_nullable
as String,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String color,  String? parentId,  String orderKey,  bool isFavorite,  bool isArchived,  bool isInbox,  String viewStyle,  bool isCollapsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.parentId,_that.orderKey,_that.isFavorite,_that.isArchived,_that.isInbox,_that.viewStyle,_that.isCollapsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String color,  String? parentId,  String orderKey,  bool isFavorite,  bool isArchived,  bool isInbox,  String viewStyle,  bool isCollapsed)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.name,_that.color,_that.parentId,_that.orderKey,_that.isFavorite,_that.isArchived,_that.isInbox,_that.viewStyle,_that.isCollapsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String color,  String? parentId,  String orderKey,  bool isFavorite,  bool isArchived,  bool isInbox,  String viewStyle,  bool isCollapsed)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.parentId,_that.orderKey,_that.isFavorite,_that.isArchived,_that.isInbox,_that.viewStyle,_that.isCollapsed);case _:
  return null;

}
}

}

/// @nodoc


class _Project implements Project {
  const _Project({required this.id, required this.name, required this.color, this.parentId, required this.orderKey, required this.isFavorite, required this.isArchived, required this.isInbox, required this.viewStyle, required this.isCollapsed});
  

@override final  String id;
@override final  String name;
/// Имя цвета палитры Todoist (`berry_red` … `taupe`).
@override final  String color;
@override final  String? parentId;
@override final  String orderKey;
@override final  bool isFavorite;
@override final  bool isArchived;
@override final  bool isInbox;
/// `list`, `board` или `calendar`; незнакомое значение — как `list`.
@override final  String viewStyle;
@override final  bool isCollapsed;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.orderKey, orderKey) || other.orderKey == orderKey)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.isInbox, isInbox) || other.isInbox == isInbox)&&(identical(other.viewStyle, viewStyle) || other.viewStyle == viewStyle)&&(identical(other.isCollapsed, isCollapsed) || other.isCollapsed == isCollapsed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,color,parentId,orderKey,isFavorite,isArchived,isInbox,viewStyle,isCollapsed);
}

@override
String toString() {
    return 'Project(id: $id, name: $name, color: $color, parentId: $parentId, orderKey: $orderKey, isFavorite: $isFavorite, isArchived: $isArchived, isInbox: $isInbox, viewStyle: $viewStyle, isCollapsed: $isCollapsed)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String color, String? parentId, String orderKey, bool isFavorite, bool isArchived, bool isInbox, String viewStyle, bool isCollapsed
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? parentId = freezed,Object? orderKey = null,Object? isFavorite = null,Object? isArchived = null,Object? isInbox = null,Object? viewStyle = null,Object? isCollapsed = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,viewStyle: null == viewStyle ? _self.viewStyle : viewStyle // ignore: cast_nullable_to_non_nullable
as String,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Section {

 String get id; String get name; String? get projectId; String get orderKey; bool get isCollapsed; bool get isArchived;
/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectionCopyWith<Section> get copyWith => _$SectionCopyWithImpl<Section>(this as Section, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Section;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Section&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.orderKey, _this.orderKey) || other.orderKey == _this.orderKey)&&(identical(other.isCollapsed, _this.isCollapsed) || other.isCollapsed == _this.isCollapsed)&&(identical(other.isArchived, _this.isArchived) || other.isArchived == _this.isArchived));
}


@override
int get hashCode {
  final _this = this as Section;
  return Object.hash(runtimeType,_this.id,_this.name,_this.projectId,_this.orderKey,_this.isCollapsed,_this.isArchived);
}

@override
String toString() {
  final _this = this as Section;
  return 'Section(id: ${_this.id}, name: ${_this.name}, projectId: ${_this.projectId}, orderKey: ${_this.orderKey}, isCollapsed: ${_this.isCollapsed}, isArchived: ${_this.isArchived})';
}


}

/// @nodoc
abstract mixin class $SectionCopyWith<$Res>  {
  factory $SectionCopyWith(Section value, $Res Function(Section) _then) = _$SectionCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? projectId, String orderKey, bool isCollapsed, bool isArchived
});




}
/// @nodoc
class _$SectionCopyWithImpl<$Res>
    implements $SectionCopyWith<$Res> {
  _$SectionCopyWithImpl(this._self, this._then);

  final Section _self;
  final $Res Function(Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? projectId = freezed,Object? orderKey = null,Object? isCollapsed = null,Object? isArchived = null,}) {
  return _then(Section(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Section].
extension SectionPatterns on Section {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Section value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Section value)  $default,){
final _that = this;
switch (_that) {
case _Section():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Section value)?  $default,){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? projectId,  String orderKey,  bool isCollapsed,  bool isArchived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.id,_that.name,_that.projectId,_that.orderKey,_that.isCollapsed,_that.isArchived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? projectId,  String orderKey,  bool isCollapsed,  bool isArchived)  $default,) {final _that = this;
switch (_that) {
case _Section():
return $default(_that.id,_that.name,_that.projectId,_that.orderKey,_that.isCollapsed,_that.isArchived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? projectId,  String orderKey,  bool isCollapsed,  bool isArchived)?  $default,) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.id,_that.name,_that.projectId,_that.orderKey,_that.isCollapsed,_that.isArchived);case _:
  return null;

}
}

}

/// @nodoc


class _Section implements Section {
  const _Section({required this.id, required this.name, this.projectId, required this.orderKey, required this.isCollapsed, required this.isArchived});
  

@override final  String id;
@override final  String name;
@override final  String? projectId;
@override final  String orderKey;
@override final  bool isCollapsed;
@override final  bool isArchived;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectionCopyWith<_Section> get copyWith => __$SectionCopyWithImpl<_Section>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Section&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.orderKey, orderKey) || other.orderKey == orderKey)&&(identical(other.isCollapsed, isCollapsed) || other.isCollapsed == isCollapsed)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,projectId,orderKey,isCollapsed,isArchived);
}

@override
String toString() {
    return 'Section(id: $id, name: $name, projectId: $projectId, orderKey: $orderKey, isCollapsed: $isCollapsed, isArchived: $isArchived)';
}


}

/// @nodoc
abstract mixin class _$SectionCopyWith<$Res> implements $SectionCopyWith<$Res> {
  factory _$SectionCopyWith(_Section value, $Res Function(_Section) _then) = __$SectionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? projectId, String orderKey, bool isCollapsed, bool isArchived
});




}
/// @nodoc
class __$SectionCopyWithImpl<$Res>
    implements _$SectionCopyWith<$Res> {
  __$SectionCopyWithImpl(this._self, this._then);

  final _Section _self;
  final $Res Function(_Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? projectId = freezed,Object? orderKey = null,Object? isCollapsed = null,Object? isArchived = null,}) {
  return _then(_Section(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Label {

 String get id; String get name; String get color; String get orderKey; bool get isFavorite;
/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelCopyWith<Label> get copyWith => _$LabelCopyWithImpl<Label>(this as Label, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Label;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Label&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.orderKey, _this.orderKey) || other.orderKey == _this.orderKey)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite));
}


@override
int get hashCode {
  final _this = this as Label;
  return Object.hash(runtimeType,_this.id,_this.name,_this.color,_this.orderKey,_this.isFavorite);
}

@override
String toString() {
  final _this = this as Label;
  return 'Label(id: ${_this.id}, name: ${_this.name}, color: ${_this.color}, orderKey: ${_this.orderKey}, isFavorite: ${_this.isFavorite})';
}


}

/// @nodoc
abstract mixin class $LabelCopyWith<$Res>  {
  factory $LabelCopyWith(Label value, $Res Function(Label) _then) = _$LabelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String color, String orderKey, bool isFavorite
});




}
/// @nodoc
class _$LabelCopyWithImpl<$Res>
    implements $LabelCopyWith<$Res> {
  _$LabelCopyWithImpl(this._self, this._then);

  final Label _self;
  final $Res Function(Label) _then;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? orderKey = null,Object? isFavorite = null,}) {
  return _then(Label(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Label].
extension LabelPatterns on Label {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Label value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Label() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Label value)  $default,){
final _that = this;
switch (_that) {
case _Label():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Label value)?  $default,){
final _that = this;
switch (_that) {
case _Label() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String color,  String orderKey,  bool isFavorite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Label() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.orderKey,_that.isFavorite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String color,  String orderKey,  bool isFavorite)  $default,) {final _that = this;
switch (_that) {
case _Label():
return $default(_that.id,_that.name,_that.color,_that.orderKey,_that.isFavorite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String color,  String orderKey,  bool isFavorite)?  $default,) {final _that = this;
switch (_that) {
case _Label() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.orderKey,_that.isFavorite);case _:
  return null;

}
}

}

/// @nodoc


class _Label implements Label {
  const _Label({required this.id, required this.name, required this.color, required this.orderKey, required this.isFavorite});
  

@override final  String id;
@override final  String name;
@override final  String color;
@override final  String orderKey;
@override final  bool isFavorite;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LabelCopyWith<_Label> get copyWith => __$LabelCopyWithImpl<_Label>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Label&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.orderKey, orderKey) || other.orderKey == orderKey)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,color,orderKey,isFavorite);
}

@override
String toString() {
    return 'Label(id: $id, name: $name, color: $color, orderKey: $orderKey, isFavorite: $isFavorite)';
}


}

/// @nodoc
abstract mixin class _$LabelCopyWith<$Res> implements $LabelCopyWith<$Res> {
  factory _$LabelCopyWith(_Label value, $Res Function(_Label) _then) = __$LabelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String color, String orderKey, bool isFavorite
});




}
/// @nodoc
class __$LabelCopyWithImpl<$Res>
    implements _$LabelCopyWith<$Res> {
  __$LabelCopyWithImpl(this._self, this._then);

  final _Label _self;
  final $Res Function(_Label) _then;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? orderKey = null,Object? isFavorite = null,}) {
  return _then(_Label(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Due {

/// `YYYY-MM-DD`.
 String get date;/// `HH:MM`; `null` — срок без времени («весь день»).
 String? get time; String? get tz;/// Срок текстом, как его ввёл пользователь («каждый пн»).
 String? get string;/// Язык, на котором разобран [string]: `ru` или `en`.
 String? get lang;/// Правило повторения; `null` — срок не повторяется.
 RecurrenceRule? get rule;
/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DueCopyWith<Due> get copyWith => _$DueCopyWithImpl<Due>(this as Due, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Due;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Due&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.tz, _this.tz) || other.tz == _this.tz)&&(identical(other.string, _this.string) || other.string == _this.string)&&(identical(other.lang, _this.lang) || other.lang == _this.lang)&&(identical(other.rule, _this.rule) || other.rule == _this.rule));
}


@override
int get hashCode {
  final _this = this as Due;
  return Object.hash(runtimeType,_this.date,_this.time,_this.tz,_this.string,_this.lang,_this.rule);
}

@override
String toString() {
  final _this = this as Due;
  return 'Due(date: ${_this.date}, time: ${_this.time}, tz: ${_this.tz}, string: ${_this.string}, lang: ${_this.lang}, rule: ${_this.rule})';
}


}

/// @nodoc
abstract mixin class $DueCopyWith<$Res>  {
  factory $DueCopyWith(Due value, $Res Function(Due) _then) = _$DueCopyWithImpl;
@useResult
$Res call({
 String date, String? time, String? tz, String? string, String? lang, RecurrenceRule? rule
});


$RecurrenceRuleCopyWith<$Res>? get rule;

}
/// @nodoc
class _$DueCopyWithImpl<$Res>
    implements $DueCopyWith<$Res> {
  _$DueCopyWithImpl(this._self, this._then);

  final Due _self;
  final $Res Function(Due) _then;

/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? time = freezed,Object? tz = freezed,Object? string = freezed,Object? lang = freezed,Object? rule = freezed,}) {
  return _then(Due(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,string: freezed == string ? _self.string : string // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,rule: freezed == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as RecurrenceRule?,
  ));
}
/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecurrenceRuleCopyWith<$Res>? get rule {
    if (_self.rule == null) {
    return null;
  }

  return $RecurrenceRuleCopyWith<$Res>(_self.rule!, (value) {
    return _then(_self.copyWith(rule: value));
  });
}
}


/// Adds pattern-matching-related methods to [Due].
extension DuePatterns on Due {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Due value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Due() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Due value)  $default,){
final _that = this;
switch (_that) {
case _Due():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Due value)?  $default,){
final _that = this;
switch (_that) {
case _Due() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String? time,  String? tz,  String? string,  String? lang,  RecurrenceRule? rule)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Due() when $default != null:
return $default(_that.date,_that.time,_that.tz,_that.string,_that.lang,_that.rule);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String? time,  String? tz,  String? string,  String? lang,  RecurrenceRule? rule)  $default,) {final _that = this;
switch (_that) {
case _Due():
return $default(_that.date,_that.time,_that.tz,_that.string,_that.lang,_that.rule);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String? time,  String? tz,  String? string,  String? lang,  RecurrenceRule? rule)?  $default,) {final _that = this;
switch (_that) {
case _Due() when $default != null:
return $default(_that.date,_that.time,_that.tz,_that.string,_that.lang,_that.rule);case _:
  return null;

}
}

}

/// @nodoc


class _Due extends Due {
  const _Due({required this.date, this.time, this.tz, this.string, this.lang, this.rule}): super._();
  

/// `YYYY-MM-DD`.
@override final  String date;
/// `HH:MM`; `null` — срок без времени («весь день»).
@override final  String? time;
@override final  String? tz;
/// Срок текстом, как его ввёл пользователь («каждый пн»).
@override final  String? string;
/// Язык, на котором разобран [string]: `ru` или `en`.
@override final  String? lang;
/// Правило повторения; `null` — срок не повторяется.
@override final  RecurrenceRule? rule;

/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DueCopyWith<_Due> get copyWith => __$DueCopyWithImpl<_Due>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Due&&(identical(other.date, date) || other.date == date)&&(identical(other.time, time) || other.time == time)&&(identical(other.tz, tz) || other.tz == tz)&&(identical(other.string, string) || other.string == string)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.rule, rule) || other.rule == rule));
}


@override
int get hashCode {
    return Object.hash(runtimeType,date,time,tz,string,lang,rule);
}

@override
String toString() {
    return 'Due(date: $date, time: $time, tz: $tz, string: $string, lang: $lang, rule: $rule)';
}


}

/// @nodoc
abstract mixin class _$DueCopyWith<$Res> implements $DueCopyWith<$Res> {
  factory _$DueCopyWith(_Due value, $Res Function(_Due) _then) = __$DueCopyWithImpl;
@override @useResult
$Res call({
 String date, String? time, String? tz, String? string, String? lang, RecurrenceRule? rule
});


@override $RecurrenceRuleCopyWith<$Res>? get rule;

}
/// @nodoc
class __$DueCopyWithImpl<$Res>
    implements _$DueCopyWith<$Res> {
  __$DueCopyWithImpl(this._self, this._then);

  final _Due _self;
  final $Res Function(_Due) _then;

/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? time = freezed,Object? tz = freezed,Object? string = freezed,Object? lang = freezed,Object? rule = freezed,}) {
  return _then(_Due(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,string: freezed == string ? _self.string : string // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,rule: freezed == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as RecurrenceRule?,
  ));
}

/// Create a copy of Due
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecurrenceRuleCopyWith<$Res>? get rule {
    if (_self.rule == null) {
    return null;
  }

  return $RecurrenceRuleCopyWith<$Res>(_self.rule!, (value) {
    return _then(_self.copyWith(rule: value));
  });
}
}

/// @nodoc
mixin _$RecurrenceRule {

/// Непустой список строк RRULE (RFC 5545) без DTSTART; конец серии —
/// `UNTIL`. Несколько правил — следующее вхождение по ближайшему.
 List<String> get rrule;/// `every!`: следующее вхождение — от даты выполнения, а не от срока.
 bool get fromCompletion;
/// Create a copy of RecurrenceRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurrenceRuleCopyWith<RecurrenceRule> get copyWith => _$RecurrenceRuleCopyWithImpl<RecurrenceRule>(this as RecurrenceRule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecurrenceRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurrenceRule&&const DeepCollectionEquality().equals(other.rrule, _this.rrule)&&(identical(other.fromCompletion, _this.fromCompletion) || other.fromCompletion == _this.fromCompletion));
}


@override
int get hashCode {
  final _this = this as RecurrenceRule;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.rrule),_this.fromCompletion);
}

@override
String toString() {
  final _this = this as RecurrenceRule;
  return 'RecurrenceRule(rrule: ${_this.rrule}, fromCompletion: ${_this.fromCompletion})';
}


}

/// @nodoc
abstract mixin class $RecurrenceRuleCopyWith<$Res>  {
  factory $RecurrenceRuleCopyWith(RecurrenceRule value, $Res Function(RecurrenceRule) _then) = _$RecurrenceRuleCopyWithImpl;
@useResult
$Res call({
 List<String> rrule, bool fromCompletion
});




}
/// @nodoc
class _$RecurrenceRuleCopyWithImpl<$Res>
    implements $RecurrenceRuleCopyWith<$Res> {
  _$RecurrenceRuleCopyWithImpl(this._self, this._then);

  final RecurrenceRule _self;
  final $Res Function(RecurrenceRule) _then;

/// Create a copy of RecurrenceRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rrule = null,Object? fromCompletion = null,}) {
  return _then(RecurrenceRule(
rrule: null == rrule ? _self.rrule : rrule // ignore: cast_nullable_to_non_nullable
as List<String>,fromCompletion: null == fromCompletion ? _self.fromCompletion : fromCompletion // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RecurrenceRule].
extension RecurrenceRulePatterns on RecurrenceRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurrenceRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurrenceRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurrenceRule value)  $default,){
final _that = this;
switch (_that) {
case _RecurrenceRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurrenceRule value)?  $default,){
final _that = this;
switch (_that) {
case _RecurrenceRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> rrule,  bool fromCompletion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurrenceRule() when $default != null:
return $default(_that.rrule,_that.fromCompletion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> rrule,  bool fromCompletion)  $default,) {final _that = this;
switch (_that) {
case _RecurrenceRule():
return $default(_that.rrule,_that.fromCompletion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> rrule,  bool fromCompletion)?  $default,) {final _that = this;
switch (_that) {
case _RecurrenceRule() when $default != null:
return $default(_that.rrule,_that.fromCompletion);case _:
  return null;

}
}

}

/// @nodoc


class _RecurrenceRule implements RecurrenceRule {
  const _RecurrenceRule({required  List<String> rrule, required this.fromCompletion}): _rrule = rrule;
  

/// Непустой список строк RRULE (RFC 5545) без DTSTART; конец серии —
/// `UNTIL`. Несколько правил — следующее вхождение по ближайшему.
 final  List<String> _rrule;
/// Непустой список строк RRULE (RFC 5545) без DTSTART; конец серии —
/// `UNTIL`. Несколько правил — следующее вхождение по ближайшему.
@override List<String> get rrule {
  if (_rrule is EqualUnmodifiableListView) return _rrule;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rrule);
}

/// `every!`: следующее вхождение — от даты выполнения, а не от срока.
@override final  bool fromCompletion;

/// Create a copy of RecurrenceRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurrenceRuleCopyWith<_RecurrenceRule> get copyWith => __$RecurrenceRuleCopyWithImpl<_RecurrenceRule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurrenceRule&&const DeepCollectionEquality().equals(other.rrule, _rrule)&&(identical(other.fromCompletion, fromCompletion) || other.fromCompletion == fromCompletion));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_rrule),fromCompletion);
}

@override
String toString() {
    return 'RecurrenceRule(rrule: $rrule, fromCompletion: $fromCompletion)';
}


}

/// @nodoc
abstract mixin class _$RecurrenceRuleCopyWith<$Res> implements $RecurrenceRuleCopyWith<$Res> {
  factory _$RecurrenceRuleCopyWith(_RecurrenceRule value, $Res Function(_RecurrenceRule) _then) = __$RecurrenceRuleCopyWithImpl;
@override @useResult
$Res call({
 List<String> rrule, bool fromCompletion
});




}
/// @nodoc
class __$RecurrenceRuleCopyWithImpl<$Res>
    implements _$RecurrenceRuleCopyWith<$Res> {
  __$RecurrenceRuleCopyWithImpl(this._self, this._then);

  final _RecurrenceRule _self;
  final $Res Function(_RecurrenceRule) _then;

/// Create a copy of RecurrenceRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rrule = null,Object? fromCompletion = null,}) {
  return _then(_RecurrenceRule(
rrule: null == rrule ? _self._rrule : rrule // ignore: cast_nullable_to_non_nullable
as List<String>,fromCompletion: null == fromCompletion ? _self.fromCompletion : fromCompletion // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$TaskDuration {

 int get amount;/// `minute` или `day`.
 String get unit;
/// Create a copy of TaskDuration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDurationCopyWith<TaskDuration> get copyWith => _$TaskDurationCopyWithImpl<TaskDuration>(this as TaskDuration, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TaskDuration;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDuration&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.unit, _this.unit) || other.unit == _this.unit));
}


@override
int get hashCode {
  final _this = this as TaskDuration;
  return Object.hash(runtimeType,_this.amount,_this.unit);
}

@override
String toString() {
  final _this = this as TaskDuration;
  return 'TaskDuration(amount: ${_this.amount}, unit: ${_this.unit})';
}


}

/// @nodoc
abstract mixin class $TaskDurationCopyWith<$Res>  {
  factory $TaskDurationCopyWith(TaskDuration value, $Res Function(TaskDuration) _then) = _$TaskDurationCopyWithImpl;
@useResult
$Res call({
 int amount, String unit
});




}
/// @nodoc
class _$TaskDurationCopyWithImpl<$Res>
    implements $TaskDurationCopyWith<$Res> {
  _$TaskDurationCopyWithImpl(this._self, this._then);

  final TaskDuration _self;
  final $Res Function(TaskDuration) _then;

/// Create a copy of TaskDuration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = null,Object? unit = null,}) {
  return _then(TaskDuration(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskDuration].
extension TaskDurationPatterns on TaskDuration {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskDuration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskDuration() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskDuration value)  $default,){
final _that = this;
switch (_that) {
case _TaskDuration():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskDuration value)?  $default,){
final _that = this;
switch (_that) {
case _TaskDuration() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int amount,  String unit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskDuration() when $default != null:
return $default(_that.amount,_that.unit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int amount,  String unit)  $default,) {final _that = this;
switch (_that) {
case _TaskDuration():
return $default(_that.amount,_that.unit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int amount,  String unit)?  $default,) {final _that = this;
switch (_that) {
case _TaskDuration() when $default != null:
return $default(_that.amount,_that.unit);case _:
  return null;

}
}

}

/// @nodoc


class _TaskDuration implements TaskDuration {
  const _TaskDuration({required this.amount, required this.unit});
  

@override final  int amount;
/// `minute` или `day`.
@override final  String unit;

/// Create a copy of TaskDuration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskDurationCopyWith<_TaskDuration> get copyWith => __$TaskDurationCopyWithImpl<_TaskDuration>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskDuration&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.unit, unit) || other.unit == unit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,amount,unit);
}

@override
String toString() {
    return 'TaskDuration(amount: $amount, unit: $unit)';
}


}

/// @nodoc
abstract mixin class _$TaskDurationCopyWith<$Res> implements $TaskDurationCopyWith<$Res> {
  factory _$TaskDurationCopyWith(_TaskDuration value, $Res Function(_TaskDuration) _then) = __$TaskDurationCopyWithImpl;
@override @useResult
$Res call({
 int amount, String unit
});




}
/// @nodoc
class __$TaskDurationCopyWithImpl<$Res>
    implements _$TaskDurationCopyWith<$Res> {
  __$TaskDurationCopyWithImpl(this._self, this._then);

  final _TaskDuration _self;
  final $Res Function(_TaskDuration) _then;

/// Create a copy of TaskDuration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = null,Object? unit = null,}) {
  return _then(_TaskDuration(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Task {

 String get id; String get content; String get description;/// `null` — «Входящие» (задача без проекта бывает, пока не пришла op).
 String? get projectId; String? get sectionId; String? get parentId; String get orderKey;/// 1 = P1 (высший) … 4 = P4 (по умолчанию).
 int get priority; Due? get due;/// Дедлайн — дата `YYYY-MM-DD`.
 String? get deadline; TaskDuration? get duration; bool get isCollapsed; bool get isCompleted;/// UTC ISO-8601.
 String? get completedAt; String? get addedAt;/// Живые метки задачи (id), по порядку меток.
 List<String> get labelIds;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Task;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.sectionId, _this.sectionId) || other.sectionId == _this.sectionId)&&(identical(other.parentId, _this.parentId) || other.parentId == _this.parentId)&&(identical(other.orderKey, _this.orderKey) || other.orderKey == _this.orderKey)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.due, _this.due) || other.due == _this.due)&&(identical(other.deadline, _this.deadline) || other.deadline == _this.deadline)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.isCollapsed, _this.isCollapsed) || other.isCollapsed == _this.isCollapsed)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&const DeepCollectionEquality().equals(other.labelIds, _this.labelIds));
}


@override
int get hashCode {
  final _this = this as Task;
  return Object.hash(runtimeType,_this.id,_this.content,_this.description,_this.projectId,_this.sectionId,_this.parentId,_this.orderKey,_this.priority,_this.due,_this.deadline,_this.duration,_this.isCollapsed,_this.isCompleted,_this.completedAt,_this.addedAt,const DeepCollectionEquality().hash(_this.labelIds));
}

@override
String toString() {
  final _this = this as Task;
  return 'Task(id: ${_this.id}, content: ${_this.content}, description: ${_this.description}, projectId: ${_this.projectId}, sectionId: ${_this.sectionId}, parentId: ${_this.parentId}, orderKey: ${_this.orderKey}, priority: ${_this.priority}, due: ${_this.due}, deadline: ${_this.deadline}, duration: ${_this.duration}, isCollapsed: ${_this.isCollapsed}, isCompleted: ${_this.isCompleted}, completedAt: ${_this.completedAt}, addedAt: ${_this.addedAt}, labelIds: ${_this.labelIds})';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String id, String content, String description, String? projectId, String? sectionId, String? parentId, String orderKey, int priority, Due? due, String? deadline, TaskDuration? duration, bool isCollapsed, bool isCompleted, String? completedAt, String? addedAt, List<String> labelIds
});


$DueCopyWith<$Res>? get due;$TaskDurationCopyWith<$Res>? get duration;

}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? content = null,Object? description = null,Object? projectId = freezed,Object? sectionId = freezed,Object? parentId = freezed,Object? orderKey = null,Object? priority = null,Object? due = freezed,Object? deadline = freezed,Object? duration = freezed,Object? isCollapsed = null,Object? isCompleted = null,Object? completedAt = freezed,Object? addedAt = freezed,Object? labelIds = null,}) {
  return _then(Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,due: freezed == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as Due?,deadline: freezed == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as TaskDuration?,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as String?,labelIds: null == labelIds ? _self.labelIds : labelIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DueCopyWith<$Res>? get due {
    if (_self.due == null) {
    return null;
  }

  return $DueCopyWith<$Res>(_self.due!, (value) {
    return _then(_self.copyWith(due: value));
  });
}/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskDurationCopyWith<$Res>? get duration {
    if (_self.duration == null) {
    return null;
  }

  return $TaskDurationCopyWith<$Res>(_self.duration!, (value) {
    return _then(_self.copyWith(duration: value));
  });
}
}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String content,  String description,  String? projectId,  String? sectionId,  String? parentId,  String orderKey,  int priority,  Due? due,  String? deadline,  TaskDuration? duration,  bool isCollapsed,  bool isCompleted,  String? completedAt,  String? addedAt,  List<String> labelIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.content,_that.description,_that.projectId,_that.sectionId,_that.parentId,_that.orderKey,_that.priority,_that.due,_that.deadline,_that.duration,_that.isCollapsed,_that.isCompleted,_that.completedAt,_that.addedAt,_that.labelIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String content,  String description,  String? projectId,  String? sectionId,  String? parentId,  String orderKey,  int priority,  Due? due,  String? deadline,  TaskDuration? duration,  bool isCollapsed,  bool isCompleted,  String? completedAt,  String? addedAt,  List<String> labelIds)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.id,_that.content,_that.description,_that.projectId,_that.sectionId,_that.parentId,_that.orderKey,_that.priority,_that.due,_that.deadline,_that.duration,_that.isCollapsed,_that.isCompleted,_that.completedAt,_that.addedAt,_that.labelIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String content,  String description,  String? projectId,  String? sectionId,  String? parentId,  String orderKey,  int priority,  Due? due,  String? deadline,  TaskDuration? duration,  bool isCollapsed,  bool isCompleted,  String? completedAt,  String? addedAt,  List<String> labelIds)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.content,_that.description,_that.projectId,_that.sectionId,_that.parentId,_that.orderKey,_that.priority,_that.due,_that.deadline,_that.duration,_that.isCollapsed,_that.isCompleted,_that.completedAt,_that.addedAt,_that.labelIds);case _:
  return null;

}
}

}

/// @nodoc


class _Task implements Task {
  const _Task({required this.id, required this.content, required this.description, this.projectId, this.sectionId, this.parentId, required this.orderKey, required this.priority, this.due, this.deadline, this.duration, required this.isCollapsed, required this.isCompleted, this.completedAt, this.addedAt,  List<String> labelIds = const <String>[]}): _labelIds = labelIds;
  

@override final  String id;
@override final  String content;
@override final  String description;
/// `null` — «Входящие» (задача без проекта бывает, пока не пришла op).
@override final  String? projectId;
@override final  String? sectionId;
@override final  String? parentId;
@override final  String orderKey;
/// 1 = P1 (высший) … 4 = P4 (по умолчанию).
@override final  int priority;
@override final  Due? due;
/// Дедлайн — дата `YYYY-MM-DD`.
@override final  String? deadline;
@override final  TaskDuration? duration;
@override final  bool isCollapsed;
@override final  bool isCompleted;
/// UTC ISO-8601.
@override final  String? completedAt;
@override final  String? addedAt;
/// Живые метки задачи (id), по порядку меток.
 final  List<String> _labelIds;
/// Живые метки задачи (id), по порядку меток.
@override@JsonKey() List<String> get labelIds {
  if (_labelIds is EqualUnmodifiableListView) return _labelIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_labelIds);
}


/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.id, id) || other.id == id)&&(identical(other.content, content) || other.content == content)&&(identical(other.description, description) || other.description == description)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.orderKey, orderKey) || other.orderKey == orderKey)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.due, due) || other.due == due)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.isCollapsed, isCollapsed) || other.isCollapsed == isCollapsed)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&const DeepCollectionEquality().equals(other.labelIds, _labelIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,content,description,projectId,sectionId,parentId,orderKey,priority,due,deadline,duration,isCollapsed,isCompleted,completedAt,addedAt,const DeepCollectionEquality().hash(_labelIds));
}

@override
String toString() {
    return 'Task(id: $id, content: $content, description: $description, projectId: $projectId, sectionId: $sectionId, parentId: $parentId, orderKey: $orderKey, priority: $priority, due: $due, deadline: $deadline, duration: $duration, isCollapsed: $isCollapsed, isCompleted: $isCompleted, completedAt: $completedAt, addedAt: $addedAt, labelIds: $labelIds)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String content, String description, String? projectId, String? sectionId, String? parentId, String orderKey, int priority, Due? due, String? deadline, TaskDuration? duration, bool isCollapsed, bool isCompleted, String? completedAt, String? addedAt, List<String> labelIds
});


@override $DueCopyWith<$Res>? get due;@override $TaskDurationCopyWith<$Res>? get duration;

}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? content = null,Object? description = null,Object? projectId = freezed,Object? sectionId = freezed,Object? parentId = freezed,Object? orderKey = null,Object? priority = null,Object? due = freezed,Object? deadline = freezed,Object? duration = freezed,Object? isCollapsed = null,Object? isCompleted = null,Object? completedAt = freezed,Object? addedAt = freezed,Object? labelIds = null,}) {
  return _then(_Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,orderKey: null == orderKey ? _self.orderKey : orderKey // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,due: freezed == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as Due?,deadline: freezed == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as TaskDuration?,isCollapsed: null == isCollapsed ? _self.isCollapsed : isCollapsed // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as String?,labelIds: null == labelIds ? _self._labelIds : labelIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DueCopyWith<$Res>? get due {
    if (_self.due == null) {
    return null;
  }

  return $DueCopyWith<$Res>(_self.due!, (value) {
    return _then(_self.copyWith(due: value));
  });
}/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskDurationCopyWith<$Res>? get duration {
    if (_self.duration == null) {
    return null;
  }

  return $TaskDurationCopyWith<$Res>(_self.duration!, (value) {
    return _then(_self.copyWith(duration: value));
  });
}
}

// dart format on

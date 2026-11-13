// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'view_options.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ViewOptions {

 ViewType get viewType;/// Id проекта, метки или фильтра; у «Сегодня» и «Предстоящего» — `null`.
 String? get objectId; Grouping get grouping; Sorting get sorting; SortOrder get sortOrder;/// «Выполненные задачи» в списке вида.
 bool get showCompletedTasks;/// Запрос фильтра «Отображения» (`filtered_by` Todoist API); `null` —
/// без фильтра. Применение и выбор — M5.3.
 String? get filteredBy;
/// Create a copy of ViewOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ViewOptionsCopyWith<ViewOptions> get copyWith => _$ViewOptionsCopyWithImpl<ViewOptions>(this as ViewOptions, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ViewOptions;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ViewOptions&&(identical(other.viewType, _this.viewType) || other.viewType == _this.viewType)&&(identical(other.objectId, _this.objectId) || other.objectId == _this.objectId)&&(identical(other.grouping, _this.grouping) || other.grouping == _this.grouping)&&(identical(other.sorting, _this.sorting) || other.sorting == _this.sorting)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.showCompletedTasks, _this.showCompletedTasks) || other.showCompletedTasks == _this.showCompletedTasks)&&(identical(other.filteredBy, _this.filteredBy) || other.filteredBy == _this.filteredBy));
}


@override
int get hashCode {
  final _this = this as ViewOptions;
  return Object.hash(runtimeType,_this.viewType,_this.objectId,_this.grouping,_this.sorting,_this.sortOrder,_this.showCompletedTasks,_this.filteredBy);
}

@override
String toString() {
  final _this = this as ViewOptions;
  return 'ViewOptions(viewType: ${_this.viewType}, objectId: ${_this.objectId}, grouping: ${_this.grouping}, sorting: ${_this.sorting}, sortOrder: ${_this.sortOrder}, showCompletedTasks: ${_this.showCompletedTasks}, filteredBy: ${_this.filteredBy})';
}


}

/// @nodoc
abstract mixin class $ViewOptionsCopyWith<$Res>  {
  factory $ViewOptionsCopyWith(ViewOptions value, $Res Function(ViewOptions) _then) = _$ViewOptionsCopyWithImpl;
@useResult
$Res call({
 ViewType viewType, String? objectId, Grouping grouping, Sorting sorting, SortOrder sortOrder, bool showCompletedTasks, String? filteredBy
});




}
/// @nodoc
class _$ViewOptionsCopyWithImpl<$Res>
    implements $ViewOptionsCopyWith<$Res> {
  _$ViewOptionsCopyWithImpl(this._self, this._then);

  final ViewOptions _self;
  final $Res Function(ViewOptions) _then;

/// Create a copy of ViewOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? viewType = null,Object? objectId = freezed,Object? grouping = null,Object? sorting = null,Object? sortOrder = null,Object? showCompletedTasks = null,Object? filteredBy = freezed,}) {
  return _then(ViewOptions(
viewType: null == viewType ? _self.viewType : viewType // ignore: cast_nullable_to_non_nullable
as ViewType,objectId: freezed == objectId ? _self.objectId : objectId // ignore: cast_nullable_to_non_nullable
as String?,grouping: null == grouping ? _self.grouping : grouping // ignore: cast_nullable_to_non_nullable
as Grouping,sorting: null == sorting ? _self.sorting : sorting // ignore: cast_nullable_to_non_nullable
as Sorting,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as SortOrder,showCompletedTasks: null == showCompletedTasks ? _self.showCompletedTasks : showCompletedTasks // ignore: cast_nullable_to_non_nullable
as bool,filteredBy: freezed == filteredBy ? _self.filteredBy : filteredBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ViewOptions].
extension ViewOptionsPatterns on ViewOptions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ViewOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ViewOptions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ViewOptions value)  $default,){
final _that = this;
switch (_that) {
case _ViewOptions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ViewOptions value)?  $default,){
final _that = this;
switch (_that) {
case _ViewOptions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ViewType viewType,  String? objectId,  Grouping grouping,  Sorting sorting,  SortOrder sortOrder,  bool showCompletedTasks,  String? filteredBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ViewOptions() when $default != null:
return $default(_that.viewType,_that.objectId,_that.grouping,_that.sorting,_that.sortOrder,_that.showCompletedTasks,_that.filteredBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ViewType viewType,  String? objectId,  Grouping grouping,  Sorting sorting,  SortOrder sortOrder,  bool showCompletedTasks,  String? filteredBy)  $default,) {final _that = this;
switch (_that) {
case _ViewOptions():
return $default(_that.viewType,_that.objectId,_that.grouping,_that.sorting,_that.sortOrder,_that.showCompletedTasks,_that.filteredBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ViewType viewType,  String? objectId,  Grouping grouping,  Sorting sorting,  SortOrder sortOrder,  bool showCompletedTasks,  String? filteredBy)?  $default,) {final _that = this;
switch (_that) {
case _ViewOptions() when $default != null:
return $default(_that.viewType,_that.objectId,_that.grouping,_that.sorting,_that.sortOrder,_that.showCompletedTasks,_that.filteredBy);case _:
  return null;

}
}

}

/// @nodoc


class _ViewOptions extends ViewOptions {
  const _ViewOptions({required this.viewType, this.objectId, this.grouping = Grouping.none, this.sorting = Sorting.byDefault, this.sortOrder = SortOrder.asc, this.showCompletedTasks = false, this.filteredBy}): super._();
  

@override final  ViewType viewType;
/// Id проекта, метки или фильтра; у «Сегодня» и «Предстоящего» — `null`.
@override final  String? objectId;
@override@JsonKey() final  Grouping grouping;
@override@JsonKey() final  Sorting sorting;
@override@JsonKey() final  SortOrder sortOrder;
/// «Выполненные задачи» в списке вида.
@override@JsonKey() final  bool showCompletedTasks;
/// Запрос фильтра «Отображения» (`filtered_by` Todoist API); `null` —
/// без фильтра. Применение и выбор — M5.3.
@override final  String? filteredBy;

/// Create a copy of ViewOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ViewOptionsCopyWith<_ViewOptions> get copyWith => __$ViewOptionsCopyWithImpl<_ViewOptions>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ViewOptions&&(identical(other.viewType, viewType) || other.viewType == viewType)&&(identical(other.objectId, objectId) || other.objectId == objectId)&&(identical(other.grouping, grouping) || other.grouping == grouping)&&(identical(other.sorting, sorting) || other.sorting == sorting)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.showCompletedTasks, showCompletedTasks) || other.showCompletedTasks == showCompletedTasks)&&(identical(other.filteredBy, filteredBy) || other.filteredBy == filteredBy));
}


@override
int get hashCode {
    return Object.hash(runtimeType,viewType,objectId,grouping,sorting,sortOrder,showCompletedTasks,filteredBy);
}

@override
String toString() {
    return 'ViewOptions(viewType: $viewType, objectId: $objectId, grouping: $grouping, sorting: $sorting, sortOrder: $sortOrder, showCompletedTasks: $showCompletedTasks, filteredBy: $filteredBy)';
}


}

/// @nodoc
abstract mixin class _$ViewOptionsCopyWith<$Res> implements $ViewOptionsCopyWith<$Res> {
  factory _$ViewOptionsCopyWith(_ViewOptions value, $Res Function(_ViewOptions) _then) = __$ViewOptionsCopyWithImpl;
@override @useResult
$Res call({
 ViewType viewType, String? objectId, Grouping grouping, Sorting sorting, SortOrder sortOrder, bool showCompletedTasks, String? filteredBy
});




}
/// @nodoc
class __$ViewOptionsCopyWithImpl<$Res>
    implements _$ViewOptionsCopyWith<$Res> {
  __$ViewOptionsCopyWithImpl(this._self, this._then);

  final _ViewOptions _self;
  final $Res Function(_ViewOptions) _then;

/// Create a copy of ViewOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? viewType = null,Object? objectId = freezed,Object? grouping = null,Object? sorting = null,Object? sortOrder = null,Object? showCompletedTasks = null,Object? filteredBy = freezed,}) {
  return _then(_ViewOptions(
viewType: null == viewType ? _self.viewType : viewType // ignore: cast_nullable_to_non_nullable
as ViewType,objectId: freezed == objectId ? _self.objectId : objectId // ignore: cast_nullable_to_non_nullable
as String?,grouping: null == grouping ? _self.grouping : grouping // ignore: cast_nullable_to_non_nullable
as Grouping,sorting: null == sorting ? _self.sorting : sorting // ignore: cast_nullable_to_non_nullable
as Sorting,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as SortOrder,showCompletedTasks: null == showCompletedTasks ? _self.showCompletedTasks : showCompletedTasks // ignore: cast_nullable_to_non_nullable
as bool,filteredBy: freezed == filteredBy ? _self.filteredBy : filteredBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

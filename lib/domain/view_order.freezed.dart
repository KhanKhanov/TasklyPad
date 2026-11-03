// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'view_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskGroupKey {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskGroupKey);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskGroupKey()';
}


}

/// @nodoc
class $TaskGroupKeyCopyWith<$Res>  {
$TaskGroupKeyCopyWith(TaskGroupKey _, $Res Function(TaskGroupKey) __);
}


/// Adds pattern-matching-related methods to [TaskGroupKey].
extension TaskGroupKeyPatterns on TaskGroupKey {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OverdueGroup value)?  overdue,TResult Function( DayGroup value)?  day,TResult Function( PriorityGroup value)?  priority,TResult Function( LabelGroup value)?  label,TResult Function( ProjectGroup value)?  project,TResult Function( EmptyGroup value)?  empty,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OverdueGroup() when overdue != null:
return overdue(_that);case DayGroup() when day != null:
return day(_that);case PriorityGroup() when priority != null:
return priority(_that);case LabelGroup() when label != null:
return label(_that);case ProjectGroup() when project != null:
return project(_that);case EmptyGroup() when empty != null:
return empty(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OverdueGroup value)  overdue,required TResult Function( DayGroup value)  day,required TResult Function( PriorityGroup value)  priority,required TResult Function( LabelGroup value)  label,required TResult Function( ProjectGroup value)  project,required TResult Function( EmptyGroup value)  empty,}){
final _that = this;
switch (_that) {
case OverdueGroup():
return overdue(_that);case DayGroup():
return day(_that);case PriorityGroup():
return priority(_that);case LabelGroup():
return label(_that);case ProjectGroup():
return project(_that);case EmptyGroup():
return empty(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OverdueGroup value)?  overdue,TResult? Function( DayGroup value)?  day,TResult? Function( PriorityGroup value)?  priority,TResult? Function( LabelGroup value)?  label,TResult? Function( ProjectGroup value)?  project,TResult? Function( EmptyGroup value)?  empty,}){
final _that = this;
switch (_that) {
case OverdueGroup() when overdue != null:
return overdue(_that);case DayGroup() when day != null:
return day(_that);case PriorityGroup() when priority != null:
return priority(_that);case LabelGroup() when label != null:
return label(_that);case ProjectGroup() when project != null:
return project(_that);case EmptyGroup() when empty != null:
return empty(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  overdue,TResult Function( String date)?  day,TResult Function( int priority)?  priority,TResult Function( String labelId)?  label,TResult Function( String projectId)?  project,TResult Function()?  empty,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OverdueGroup() when overdue != null:
return overdue();case DayGroup() when day != null:
return day(_that.date);case PriorityGroup() when priority != null:
return priority(_that.priority);case LabelGroup() when label != null:
return label(_that.labelId);case ProjectGroup() when project != null:
return project(_that.projectId);case EmptyGroup() when empty != null:
return empty();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  overdue,required TResult Function( String date)  day,required TResult Function( int priority)  priority,required TResult Function( String labelId)  label,required TResult Function( String projectId)  project,required TResult Function()  empty,}) {final _that = this;
switch (_that) {
case OverdueGroup():
return overdue();case DayGroup():
return day(_that.date);case PriorityGroup():
return priority(_that.priority);case LabelGroup():
return label(_that.labelId);case ProjectGroup():
return project(_that.projectId);case EmptyGroup():
return empty();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  overdue,TResult? Function( String date)?  day,TResult? Function( int priority)?  priority,TResult? Function( String labelId)?  label,TResult? Function( String projectId)?  project,TResult? Function()?  empty,}) {final _that = this;
switch (_that) {
case OverdueGroup() when overdue != null:
return overdue();case DayGroup() when day != null:
return day(_that.date);case PriorityGroup() when priority != null:
return priority(_that.priority);case LabelGroup() when label != null:
return label(_that.labelId);case ProjectGroup() when project != null:
return project(_that.projectId);case EmptyGroup() when empty != null:
return empty();case _:
  return null;

}
}

}

/// @nodoc


class OverdueGroup implements TaskGroupKey {
  const OverdueGroup();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OverdueGroup);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskGroupKey.overdue()';
}


}




/// @nodoc


class DayGroup implements TaskGroupKey {
  const DayGroup(this.date);
  

 final  String date;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayGroupCopyWith<DayGroup> get copyWith => _$DayGroupCopyWithImpl<DayGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DayGroup&&(identical(other.date, date) || other.date == date));
}


@override
int get hashCode {
    return Object.hash(runtimeType,date);
}

@override
String toString() {
    return 'TaskGroupKey.day(date: $date)';
}


}

/// @nodoc
abstract mixin class $DayGroupCopyWith<$Res> implements $TaskGroupKeyCopyWith<$Res> {
  factory $DayGroupCopyWith(DayGroup value, $Res Function(DayGroup) _then) = _$DayGroupCopyWithImpl;
@useResult
$Res call({
 String date
});




}
/// @nodoc
class _$DayGroupCopyWithImpl<$Res>
    implements $DayGroupCopyWith<$Res> {
  _$DayGroupCopyWithImpl(this._self, this._then);

  final DayGroup _self;
  final $Res Function(DayGroup) _then;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? date = null,}) {
  return _then(DayGroup(
null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PriorityGroup implements TaskGroupKey {
  const PriorityGroup(this.priority);
  

 final  int priority;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PriorityGroupCopyWith<PriorityGroup> get copyWith => _$PriorityGroupCopyWithImpl<PriorityGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PriorityGroup&&(identical(other.priority, priority) || other.priority == priority));
}


@override
int get hashCode {
    return Object.hash(runtimeType,priority);
}

@override
String toString() {
    return 'TaskGroupKey.priority(priority: $priority)';
}


}

/// @nodoc
abstract mixin class $PriorityGroupCopyWith<$Res> implements $TaskGroupKeyCopyWith<$Res> {
  factory $PriorityGroupCopyWith(PriorityGroup value, $Res Function(PriorityGroup) _then) = _$PriorityGroupCopyWithImpl;
@useResult
$Res call({
 int priority
});




}
/// @nodoc
class _$PriorityGroupCopyWithImpl<$Res>
    implements $PriorityGroupCopyWith<$Res> {
  _$PriorityGroupCopyWithImpl(this._self, this._then);

  final PriorityGroup _self;
  final $Res Function(PriorityGroup) _then;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? priority = null,}) {
  return _then(PriorityGroup(
null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class LabelGroup implements TaskGroupKey {
  const LabelGroup(this.labelId);
  

 final  String labelId;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelGroupCopyWith<LabelGroup> get copyWith => _$LabelGroupCopyWithImpl<LabelGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelGroup&&(identical(other.labelId, labelId) || other.labelId == labelId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,labelId);
}

@override
String toString() {
    return 'TaskGroupKey.label(labelId: $labelId)';
}


}

/// @nodoc
abstract mixin class $LabelGroupCopyWith<$Res> implements $TaskGroupKeyCopyWith<$Res> {
  factory $LabelGroupCopyWith(LabelGroup value, $Res Function(LabelGroup) _then) = _$LabelGroupCopyWithImpl;
@useResult
$Res call({
 String labelId
});




}
/// @nodoc
class _$LabelGroupCopyWithImpl<$Res>
    implements $LabelGroupCopyWith<$Res> {
  _$LabelGroupCopyWithImpl(this._self, this._then);

  final LabelGroup _self;
  final $Res Function(LabelGroup) _then;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? labelId = null,}) {
  return _then(LabelGroup(
null == labelId ? _self.labelId : labelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ProjectGroup implements TaskGroupKey {
  const ProjectGroup(this.projectId);
  

 final  String projectId;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectGroupCopyWith<ProjectGroup> get copyWith => _$ProjectGroupCopyWithImpl<ProjectGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectGroup&&(identical(other.projectId, projectId) || other.projectId == projectId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,projectId);
}

@override
String toString() {
    return 'TaskGroupKey.project(projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class $ProjectGroupCopyWith<$Res> implements $TaskGroupKeyCopyWith<$Res> {
  factory $ProjectGroupCopyWith(ProjectGroup value, $Res Function(ProjectGroup) _then) = _$ProjectGroupCopyWithImpl;
@useResult
$Res call({
 String projectId
});




}
/// @nodoc
class _$ProjectGroupCopyWithImpl<$Res>
    implements $ProjectGroupCopyWith<$Res> {
  _$ProjectGroupCopyWithImpl(this._self, this._then);

  final ProjectGroup _self;
  final $Res Function(ProjectGroup) _then;

/// Create a copy of TaskGroupKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectId = null,}) {
  return _then(ProjectGroup(
null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class EmptyGroup implements TaskGroupKey {
  const EmptyGroup();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmptyGroup);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskGroupKey.empty()';
}


}




// dart format on

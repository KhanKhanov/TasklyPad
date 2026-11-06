// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Выделение задач. Сбрасывается при смене вида (оболочка) и после действия
/// над выделенными.

@ProviderFor(TaskSelection)
final taskSelectionProvider = TaskSelectionProvider._();

/// Выделение задач. Сбрасывается при смене вида (оболочка) и после действия
/// над выделенными.
final class TaskSelectionProvider
    extends $NotifierProvider<TaskSelection, TaskSelectionState> {
  /// Выделение задач. Сбрасывается при смене вида (оболочка) и после действия
  /// над выделенными.
  TaskSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSelectionHash();

  @$internal
  @override
  TaskSelection create() => TaskSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSelectionState>(value),
    );
  }
}

String _$taskSelectionHash() => r'cd1f09e85f1b63614d8fe8ce6dabc1e1de7bb015';

/// Выделение задач. Сбрасывается при смене вида (оболочка) и после действия
/// над выделенными.

abstract class _$TaskSelection extends $Notifier<TaskSelectionState> {
  TaskSelectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TaskSelectionState, TaskSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskSelectionState, TaskSelectionState>,
              TaskSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

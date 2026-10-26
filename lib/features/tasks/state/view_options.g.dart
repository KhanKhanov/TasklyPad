// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_options.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
///
/// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
/// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).

@ProviderFor(ShowCompleted)
final showCompletedProvider = ShowCompletedFamily._();

/// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
///
/// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
/// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).
final class ShowCompletedProvider
    extends $NotifierProvider<ShowCompleted, bool> {
  /// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
  ///
  /// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
  /// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).
  ShowCompletedProvider._({
    required ShowCompletedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'showCompletedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showCompletedHash();

  @override
  String toString() {
    return r'showCompletedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ShowCompleted create() => ShowCompleted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ShowCompletedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showCompletedHash() => r'd219cb6936a189f77e0339fcc11e2e486936f7bf';

/// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
///
/// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
/// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).

final class ShowCompletedFamily extends $Family
    with $ClassFamilyOverride<ShowCompleted, bool, bool, bool, String> {
  ShowCompletedFamily._()
    : super(
        retry: null,
        name: r'showCompletedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
  ///
  /// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
  /// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).

  ShowCompletedProvider call(String viewId) =>
      ShowCompletedProvider._(argument: viewId, from: this);

  @override
  String toString() => r'showCompletedProvider';
}

/// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
///
/// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
/// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).

abstract class _$ShowCompleted extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get viewId => _$args;

  bool build(String viewId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

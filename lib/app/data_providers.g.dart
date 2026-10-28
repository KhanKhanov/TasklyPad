// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceRepository,
          WorkspaceRepository,
          WorkspaceRepository
        >
    with $Provider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceRepository create(Ref ref) {
    return workspaceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceRepository>(value),
    );
  }
}

String _$workspaceRepositoryHash() =>
    r'880d60e23700160c61309921e753311bc259a3ac';

/// Снимок данных пользователя; обновляется после каждого изменения таблиц —
/// и своего, и пришедшего синхронизацией.

@ProviderFor(workspace)
final workspaceProvider = WorkspaceProvider._();

/// Снимок данных пользователя; обновляется после каждого изменения таблиц —
/// и своего, и пришедшего синхронизацией.

final class WorkspaceProvider
    extends
        $FunctionalProvider<AsyncValue<Workspace>, Workspace, Stream<Workspace>>
    with $FutureModifier<Workspace>, $StreamProvider<Workspace> {
  /// Снимок данных пользователя; обновляется после каждого изменения таблиц —
  /// и своего, и пришедшего синхронизацией.
  WorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceHash();

  @$internal
  @override
  $StreamProviderElement<Workspace> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Workspace> create(Ref ref) {
    return workspace(ref);
  }
}

String _$workspaceHash() => r'4618a6219ae0cae8cbaa96c4876ee3cde6d6f038';

/// Часы приложения — для «сегодня» на экранах (сроки, быстрые даты). В
/// тестах — часы тестового устройства.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// Часы приложения — для «сегодня» на экранах (сроки, быстрые даты). В
/// тестах — часы тестового устройства.

final class ClockProvider
    extends $FunctionalProvider<AppClock, AppClock, AppClock>
    with $Provider<AppClock> {
  /// Часы приложения — для «сегодня» на экранах (сроки, быстрые даты). В
  /// тестах — часы тестового устройства.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<AppClock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppClock create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppClock>(value),
    );
  }
}

String _$clockHash() => r'9b073d37c2a85475272a515d9ad9145df3b5d3db';

@ProviderFor(taskCommands)
final taskCommandsProvider = TaskCommandsProvider._();

final class TaskCommandsProvider
    extends $FunctionalProvider<TaskCommands, TaskCommands, TaskCommands>
    with $Provider<TaskCommands> {
  TaskCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskCommandsHash();

  @$internal
  @override
  $ProviderElement<TaskCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskCommands create(Ref ref) {
    return taskCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskCommands>(value),
    );
  }
}

String _$taskCommandsHash() => r'cb40b8321fc0d6a92d1f27df269bf035865f037e';

@ProviderFor(projectCommands)
final projectCommandsProvider = ProjectCommandsProvider._();

final class ProjectCommandsProvider
    extends
        $FunctionalProvider<ProjectCommands, ProjectCommands, ProjectCommands>
    with $Provider<ProjectCommands> {
  ProjectCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectCommandsHash();

  @$internal
  @override
  $ProviderElement<ProjectCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProjectCommands create(Ref ref) {
    return projectCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectCommands>(value),
    );
  }
}

String _$projectCommandsHash() => r'0f628598509c0b799dd7276ec75b02d3b4c32138';

@ProviderFor(sectionCommands)
final sectionCommandsProvider = SectionCommandsProvider._();

final class SectionCommandsProvider
    extends
        $FunctionalProvider<SectionCommands, SectionCommands, SectionCommands>
    with $Provider<SectionCommands> {
  SectionCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sectionCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sectionCommandsHash();

  @$internal
  @override
  $ProviderElement<SectionCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SectionCommands create(Ref ref) {
    return sectionCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SectionCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SectionCommands>(value),
    );
  }
}

String _$sectionCommandsHash() => r'2060b5aa16a4602a9d476e07f4d61db6601fcf4f';

@ProviderFor(labelCommands)
final labelCommandsProvider = LabelCommandsProvider._();

final class LabelCommandsProvider
    extends $FunctionalProvider<LabelCommands, LabelCommands, LabelCommands>
    with $Provider<LabelCommands> {
  LabelCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'labelCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$labelCommandsHash();

  @$internal
  @override
  $ProviderElement<LabelCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LabelCommands create(Ref ref) {
    return labelCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LabelCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LabelCommands>(value),
    );
  }
}

String _$labelCommandsHash() => r'2727eaa555f0f54059cbdc8de0e0ad3f5610282f';

@ProviderFor(conflictRepository)
final conflictRepositoryProvider = ConflictRepositoryProvider._();

final class ConflictRepositoryProvider
    extends
        $FunctionalProvider<
          ConflictRepository,
          ConflictRepository,
          ConflictRepository
        >
    with $Provider<ConflictRepository> {
  ConflictRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conflictRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conflictRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConflictRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConflictRepository create(Ref ref) {
    return conflictRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConflictRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConflictRepository>(value),
    );
  }
}

String _$conflictRepositoryHash() =>
    r'083efb66f03579c00e5d51cb68b63038c9edf289';

/// Открытые конфликты карточками, новые сверху (экран и пункт сайдбара).

@ProviderFor(openConflicts)
final openConflictsProvider = OpenConflictsProvider._();

/// Открытые конфликты карточками, новые сверху (экран и пункт сайдбара).

final class OpenConflictsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConflictCard>>,
          List<ConflictCard>,
          Stream<List<ConflictCard>>
        >
    with
        $FutureModifier<List<ConflictCard>>,
        $StreamProvider<List<ConflictCard>> {
  /// Открытые конфликты карточками, новые сверху (экран и пункт сайдбара).
  OpenConflictsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openConflictsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openConflictsHash();

  @$internal
  @override
  $StreamProviderElement<List<ConflictCard>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ConflictCard>> create(Ref ref) {
    return openConflicts(ref);
  }
}

String _$openConflictsHash() => r'39f8a95cc333214eb1d33dec54c0ba6b3d51ac67';

@ProviderFor(conflictCommands)
final conflictCommandsProvider = ConflictCommandsProvider._();

final class ConflictCommandsProvider
    extends
        $FunctionalProvider<
          ConflictCommands,
          ConflictCommands,
          ConflictCommands
        >
    with $Provider<ConflictCommands> {
  ConflictCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conflictCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conflictCommandsHash();

  @$internal
  @override
  $ProviderElement<ConflictCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConflictCommands create(Ref ref) {
    return conflictCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConflictCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConflictCommands>(value),
    );
  }
}

String _$conflictCommandsHash() => r'3ac7ab5ce24961099674b3fe696bebcd54ea5dc7';

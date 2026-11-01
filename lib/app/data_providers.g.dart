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

String _$taskCommandsHash() => r'baf2c263653868e9196dc655c0ad0d63f7894108';

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'2de17899c89cd144d3e134172002d79d8b2f2dfd';

/// «Умное распознавание дат» — своё и пришедшее синхронизацией.

@ProviderFor(smartDateRecognition)
final smartDateRecognitionProvider = SmartDateRecognitionProvider._();

/// «Умное распознавание дат» — своё и пришедшее синхронизацией.

final class SmartDateRecognitionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// «Умное распознавание дат» — своё и пришедшее синхронизацией.
  SmartDateRecognitionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartDateRecognitionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartDateRecognitionHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return smartDateRecognition(ref);
  }
}

String _$smartDateRecognitionHash() =>
    r'dbfbaa73f4fcf3f365bed7ae796be9bd0c67168b';

/// «Добавлять подзадачи снова» — своё и пришедшее синхронизацией.

@ProviderFor(resetRecurringSubtasks)
final resetRecurringSubtasksProvider = ResetRecurringSubtasksProvider._();

/// «Добавлять подзадачи снова» — своё и пришедшее синхронизацией.

final class ResetRecurringSubtasksProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// «Добавлять подзадачи снова» — своё и пришедшее синхронизацией.
  ResetRecurringSubtasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resetRecurringSubtasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resetRecurringSubtasksHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return resetRecurringSubtasks(ref);
  }
}

String _$resetRecurringSubtasksHash() =>
    r'207e85c0a3843bb6328fbce14011fd6ce5863d5f';

@ProviderFor(generalSettingsCommands)
final generalSettingsCommandsProvider = GeneralSettingsCommandsProvider._();

final class GeneralSettingsCommandsProvider
    extends
        $FunctionalProvider<
          GeneralSettingsCommands,
          GeneralSettingsCommands,
          GeneralSettingsCommands
        >
    with $Provider<GeneralSettingsCommands> {
  GeneralSettingsCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'generalSettingsCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$generalSettingsCommandsHash();

  @$internal
  @override
  $ProviderElement<GeneralSettingsCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GeneralSettingsCommands create(Ref ref) {
    return generalSettingsCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeneralSettingsCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeneralSettingsCommands>(value),
    );
  }
}

String _$generalSettingsCommandsHash() =>
    r'7691d2e3c6cbf1cca5a114dfc507ba03a3682154';

@ProviderFor(quickAddCommands)
final quickAddCommandsProvider = QuickAddCommandsProvider._();

final class QuickAddCommandsProvider
    extends
        $FunctionalProvider<
          QuickAddCommands,
          QuickAddCommands,
          QuickAddCommands
        >
    with $Provider<QuickAddCommands> {
  QuickAddCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickAddCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickAddCommandsHash();

  @$internal
  @override
  $ProviderElement<QuickAddCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QuickAddCommands create(Ref ref) {
    return quickAddCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuickAddCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuickAddCommands>(value),
    );
  }
}

String _$quickAddCommandsHash() => r'94be56001bc27dead1915bd7f40f12340123f292';

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

String _$conflictCommandsHash() => r'729c046abf53f42184de61938c3f84ef1a9ab4c2';

@ProviderFor(themeSettingsRepository)
final themeSettingsRepositoryProvider = ThemeSettingsRepositoryProvider._();

final class ThemeSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          ThemeSettingsRepository,
          ThemeSettingsRepository,
          ThemeSettingsRepository
        >
    with $Provider<ThemeSettingsRepository> {
  ThemeSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeSettingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeSettingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ThemeSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ThemeSettingsRepository create(Ref ref) {
    return themeSettingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeSettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeSettingsRepository>(value),
    );
  }
}

String _$themeSettingsRepositoryHash() =>
    r'02297d083524bf20539697a82f3fa374bd97d506';

/// Настройки темы, прочитанные до первого кадра (`main`): без них приложение
/// с сохранённой тёмной темой мигнуло бы светлой, пока поток не ответит.

@ProviderFor(initialThemeSettings)
final initialThemeSettingsProvider = InitialThemeSettingsProvider._();

/// Настройки темы, прочитанные до первого кадра (`main`): без них приложение
/// с сохранённой тёмной темой мигнуло бы светлой, пока поток не ответит.

final class InitialThemeSettingsProvider
    extends $FunctionalProvider<ThemeSettings, ThemeSettings, ThemeSettings>
    with $Provider<ThemeSettings> {
  /// Настройки темы, прочитанные до первого кадра (`main`): без них приложение
  /// с сохранённой тёмной темой мигнуло бы светлой, пока поток не ответит.
  InitialThemeSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialThemeSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialThemeSettingsHash();

  @$internal
  @override
  $ProviderElement<ThemeSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeSettings create(Ref ref) {
    return initialThemeSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeSettings>(value),
    );
  }
}

String _$initialThemeSettingsHash() =>
    r'6189749e4a0b95294cd5e7aceeedd74106d7735a';

/// Настройки темы — свои и пришедшие синхронизацией.

@ProviderFor(themeSettings)
final themeSettingsProvider = ThemeSettingsProvider._();

/// Настройки темы — свои и пришедшие синхронизацией.

final class ThemeSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ThemeSettings>,
          ThemeSettings,
          Stream<ThemeSettings>
        >
    with $FutureModifier<ThemeSettings>, $StreamProvider<ThemeSettings> {
  /// Настройки темы — свои и пришедшие синхронизацией.
  ThemeSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeSettingsHash();

  @$internal
  @override
  $StreamProviderElement<ThemeSettings> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ThemeSettings> create(Ref ref) {
    return themeSettings(ref);
  }
}

String _$themeSettingsHash() => r'9ed7aa062b535f9af91393dcbe544ad897dcb179';

@ProviderFor(themeCommands)
final themeCommandsProvider = ThemeCommandsProvider._();

final class ThemeCommandsProvider
    extends $FunctionalProvider<ThemeCommands, ThemeCommands, ThemeCommands>
    with $Provider<ThemeCommands> {
  ThemeCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeCommandsHash();

  @$internal
  @override
  $ProviderElement<ThemeCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeCommands create(Ref ref) {
    return themeCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeCommands>(value),
    );
  }
}

String _$themeCommandsHash() => r'1b428ce9f30113a62cb14149ddd5aa19e09b46ed';

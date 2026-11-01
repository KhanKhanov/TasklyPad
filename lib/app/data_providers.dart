import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/clock.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/theme_settings_repository.dart';
import '../data/repositories/workspace_repository.dart';
import '../domain/conflicts.dart';
import '../domain/theme_settings.dart';
import '../domain/workspace.dart';
import '../features/conflicts/logic/conflict_commands.dart';
import '../features/labels/logic/label_commands.dart';
import '../features/projects/logic/project_commands.dart';
import '../features/quick_add/logic/quick_add_commands.dart';
import '../features/sections/logic/section_commands.dart';
import '../features/settings/logic/general_settings_commands.dart';
import '../features/settings/logic/theme_commands.dart';
import '../features/tasks/logic/task_commands.dart';
import '../sync/conflict_repository.dart';
import 'sync_providers.dart';

part 'data_providers.g.dart';

// Чтение и действия для экранов. UI не видит drift: читает снимок
// [Workspace], пишет через *Commands (а те — через Mutator).

@Riverpod(keepAlive: true)
WorkspaceRepository workspaceRepository(Ref ref) =>
    WorkspaceRepository(ref.watch(appDatabaseProvider));

/// Снимок данных пользователя; обновляется после каждого изменения таблиц —
/// и своего, и пришедшего синхронизацией.
@Riverpod(keepAlive: true)
Stream<Workspace> workspace(Ref ref) =>
    ref.watch(workspaceRepositoryProvider).watch();

/// Часы приложения — для «сегодня» на экранах (сроки, быстрые даты). В
/// тестах — часы тестового устройства.
@Riverpod(keepAlive: true)
AppClock clock(Ref ref) => ref.watch(syncServicesProvider).clock;

@Riverpod(keepAlive: true)
TaskCommands taskCommands(Ref ref) {
  final services = ref.watch(syncServicesProvider);
  return TaskCommands(
    mutator: services.mutator,
    read: ref.watch(workspaceRepositoryProvider).load,
    clock: services.clock,
    resetRecurringSubtasks: ref
        .watch(settingsRepositoryProvider)
        .resetRecurringSubtasks,
  );
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

/// «Умное распознавание дат» — своё и пришедшее синхронизацией.
@Riverpod(keepAlive: true)
Stream<bool> smartDateRecognition(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchSmartDateRecognition();

@Riverpod(keepAlive: true)
GeneralSettingsCommands generalSettingsCommands(Ref ref) =>
    GeneralSettingsCommands(mutator: ref.watch(mutatorProvider));

@Riverpod(keepAlive: true)
QuickAddCommands quickAddCommands(Ref ref) => QuickAddCommands(
  mutator: ref.watch(mutatorProvider),
  read: ref.watch(workspaceRepositoryProvider).load,
  tasks: ref.watch(taskCommandsProvider),
  projects: ref.watch(projectCommandsProvider),
  labels: ref.watch(labelCommandsProvider),
);

@Riverpod(keepAlive: true)
ProjectCommands projectCommands(Ref ref) => ProjectCommands(
  mutator: ref.watch(mutatorProvider),
  read: ref.watch(workspaceRepositoryProvider).load,
  tasks: ref.watch(taskCommandsProvider),
);

@Riverpod(keepAlive: true)
SectionCommands sectionCommands(Ref ref) => SectionCommands(
  mutator: ref.watch(mutatorProvider),
  read: ref.watch(workspaceRepositoryProvider).load,
  tasks: ref.watch(taskCommandsProvider),
);

@Riverpod(keepAlive: true)
LabelCommands labelCommands(Ref ref) => LabelCommands(
  mutator: ref.watch(mutatorProvider),
  read: ref.watch(workspaceRepositoryProvider).load,
);

@Riverpod(keepAlive: true)
ConflictRepository conflictRepository(Ref ref) {
  final services = ref.watch(syncServicesProvider);
  return ConflictRepository(
    db: services.db,
    store: services.store,
    meta: services.meta,
  );
}

/// Открытые конфликты карточками, новые сверху (экран и пункт сайдбара).
@Riverpod(keepAlive: true)
Stream<List<ConflictCard>> openConflicts(Ref ref) =>
    ref.watch(conflictRepositoryProvider).watch();

@Riverpod(keepAlive: true)
ConflictCommands conflictCommands(Ref ref) => ConflictCommands(
  mutator: ref.watch(mutatorProvider),
  read: ref.watch(workspaceRepositoryProvider).load,
);

@Riverpod(keepAlive: true)
ThemeSettingsRepository themeSettingsRepository(Ref ref) =>
    ThemeSettingsRepository(ref.watch(appDatabaseProvider));

/// Настройки темы, прочитанные до первого кадра (`main`): без них приложение
/// с сохранённой тёмной темой мигнуло бы светлой, пока поток не ответит.
@Riverpod(keepAlive: true)
ThemeSettings initialThemeSettings(Ref ref) => const ThemeSettings();

/// Настройки темы — свои и пришедшие синхронизацией.
@Riverpod(keepAlive: true)
Stream<ThemeSettings> themeSettings(Ref ref) =>
    ref.watch(themeSettingsRepositoryProvider).watch();

@Riverpod(keepAlive: true)
ThemeCommands themeCommands(Ref ref) {
  final services = ref.watch(syncServicesProvider);
  return ThemeCommands(
    mutator: services.mutator,
    meta: services.meta,
    read: ref.watch(themeSettingsRepositoryProvider).load,
  );
}

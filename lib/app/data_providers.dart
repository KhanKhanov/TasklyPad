import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/clock.dart';
import '../data/repositories/workspace_repository.dart';
import '../domain/workspace.dart';
import '../features/labels/logic/label_commands.dart';
import '../features/projects/logic/project_commands.dart';
import '../features/sections/logic/section_commands.dart';
import '../features/tasks/logic/task_commands.dart';
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
  );
}

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

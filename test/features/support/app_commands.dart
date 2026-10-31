import 'package:planner/data/repositories/settings_repository.dart';
import 'package:planner/data/repositories/theme_settings_repository.dart';
import 'package:planner/data/repositories/workspace_repository.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/labels/logic/label_commands.dart';
import 'package:planner/features/projects/logic/project_commands.dart';
import 'package:planner/features/sections/logic/section_commands.dart';
import 'package:planner/features/settings/logic/theme_commands.dart';
import 'package:planner/features/tasks/logic/task_commands.dart';

import '../../sync/support/devices.dart';

/// Действия и чтение одного тестового устройства — как их соберёт приложение.
final class AppCommands {
  AppCommands(TestDevice device) : repo = WorkspaceRepository(device.db) {
    final mutator = device.services.mutator;
    tasks = TaskCommands(
      mutator: mutator,
      read: repo.load,
      clock: device.clock,
      resetRecurringSubtasks: SettingsRepository(device.db)
          .resetRecurringSubtasks,
    );
    projects = ProjectCommands(mutator: mutator, read: repo.load, tasks: tasks);
    sections = SectionCommands(mutator: mutator, read: repo.load, tasks: tasks);
    labels = LabelCommands(mutator: mutator, read: repo.load);
    themeRepo = ThemeSettingsRepository(device.db);
    theme = ThemeCommands(
      mutator: mutator,
      meta: device.services.meta,
      read: themeRepo.load,
    );
  }

  final WorkspaceRepository repo;
  late final ThemeCommands theme;
  late final ThemeSettingsRepository themeRepo;
  late final TaskCommands tasks;
  late final ProjectCommands projects;
  late final SectionCommands sections;
  late final LabelCommands labels;

  Future<Workspace> read() => repo.load();
}

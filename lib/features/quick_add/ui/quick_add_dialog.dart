import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/quick_add_draft.dart';
import 'quick_add_composer.dart';

/// Место новой задачи по открытому экрану (решение 2А «Ход M3.6»): проект —
/// в него, метка — во «Входящие» с этой меткой, остальное — «Входящие».
/// `null` — «Входящих» ещё нет (до первого запуска ядра данных).
QuickAddDefaults? quickAddDefaultsFor(Workspace ws, String location) {
  final inbox = ws.inbox;
  if (inbox == null) return null;
  final segments = Uri.parse(location).pathSegments;
  if (segments.length == 2) {
    final id = segments[1];
    if (segments.first == 'project') {
      final project = ws.project(id);
      if (project != null && !ws.isProjectArchived(id)) {
        return QuickAddDefaults(projectId: project.id);
      }
    } else if (segments.first == 'label' && ws.label(id) != null) {
      return QuickAddDefaults(projectId: inbox.id, labelIds: {id});
    }
  }
  return QuickAddDefaults(projectId: inbox.id);
}

/// Окно быстрого добавления (`q`, «Добавить задачу» в сайдбаре): поверх
/// приложения, у верхнего края. После добавления окно закрывается и внизу
/// появляется «Задача добавлена» (допущение О-57: в help не описано).
Future<void> showQuickAddDialog(
  BuildContext context,
  QuickAddDefaults defaults,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
      backgroundColor: AppPalette.of(context).raised,
      child: Semantics(
        label: l10n.quickAdd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: QuickAddComposer(
              defaults: defaults,
              descriptionOpen: false,
              onClose: () => Navigator.pop(context),
              onAdded: (count) {
                Navigator.pop(context);
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(l10n.quickAddTaskAdded),
                    behavior: SnackBarBehavior.floating,
                    width: 360,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// Окно быстрого добавления с местом открытого экрана [location] (`q` и
/// «Добавить задачу» в сайдбаре).
void openQuickAdd(BuildContext context, WidgetRef ref, String location) {
  final ws = ref.read(workspaceProvider).value;
  final defaults = ws == null ? null : quickAddDefaultsFor(ws, location);
  if (defaults != null) showQuickAddDialog(context, defaults);
}

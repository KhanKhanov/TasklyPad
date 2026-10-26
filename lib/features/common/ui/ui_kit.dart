import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';

/// Перейти на экран; открытая выдвижная панель (узкое окно) закрывается, как
/// в Todoist на телефоне.
void navigate(BuildContext context, String path) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  context.go(path);
}

/// Снимок данных для экрана: пока грузится — пусто, при ошибке — сообщение и
/// запись в журнал (ошибку не глотаем), иначе — [builder].
class WorkspaceView extends ConsumerWidget {
  const WorkspaceView({super.key, required this.builder});

  final Widget Function(BuildContext context, Workspace ws) builder;

  static final Logger _logger = Logger();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(workspaceProvider)) {
        AsyncData(:final value) => builder(context, value),
        AsyncError(:final error, :final stackTrace) => _error(
          context,
          error,
          stackTrace,
        ),
        _ => const SizedBox.shrink(),
      };

  Widget _error(BuildContext context, Object error, StackTrace stack) {
    _logger.e('Снимок данных не загрузился', error: error, stackTrace: stack);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context).loadError('$error'),
          style: TextStyle(color: AppPalette.of(context).danger),
        ),
      ),
    );
  }
}

/// Имя проекта для показа: «Входящие» — переводом, а не записанным `Inbox`.
String projectTitle(AppLocalizations l10n, Project project) =>
    project.isInbox ? l10n.inbox : project.name;

/// Текст отказа правилами ([CommandRejected]).
String rejectMessage(AppLocalizations l10n, RejectReason reason) =>
    switch (reason) {
      RejectReason.emptyName => l10n.rejectEmptyName,
      RejectReason.inboxProtected => l10n.rejectInboxProtected,
      RejectReason.tooDeep => l10n.rejectTooDeep,
      RejectReason.cycle => l10n.rejectCycle,
      RejectReason.tooManySections => l10n.rejectTooManySections,
      RejectReason.duplicateName => l10n.rejectDuplicateName,
      RejectReason.notFound => l10n.rejectNotFound,
    };

/// Выполнить действие; отказ правилами — короткое сообщение внизу экрана.
/// Прочие ошибки не глотаются.
Future<void> runCommand(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await action();
  } on CommandRejected catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(rejectMessage(l10n, e.reason))),
    );
  }
}

/// Подтверждение опасного действия. `true` — пользователь согласился.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final palette = AppPalette.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: palette.danger)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Название цвета палитры по ключу данных.
String colorName(AppLocalizations l10n, String key) => switch (key) {
  'berry_red' => l10n.colorBerryRed,
  'red' => l10n.colorRed,
  'orange' => l10n.colorOrange,
  'yellow' => l10n.colorYellow,
  'olive_green' => l10n.colorOliveGreen,
  'lime_green' => l10n.colorLimeGreen,
  'green' => l10n.colorGreen,
  'mint_green' => l10n.colorMintGreen,
  'teal' => l10n.colorTeal,
  'sky_blue' => l10n.colorSkyBlue,
  'light_blue' => l10n.colorLightBlue,
  'blue' => l10n.colorBlue,
  'grape' => l10n.colorGrape,
  'violet' => l10n.colorViolet,
  'lavender' => l10n.colorLavender,
  'magenta' => l10n.colorMagenta,
  'salmon' => l10n.colorSalmon,
  'grey' => l10n.colorGrey,
  'taupe' => l10n.colorTaupe,
  _ => l10n.colorCharcoal,
};

/// Значок проекта, как в Todoist: `#` цвета проекта.
class ProjectHash extends StatelessWidget {
  const ProjectHash({super.key, required this.color, this.size = 18});

  final String color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size + 6,
    child: Text(
      '#',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: projectColor(color),
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    ),
  );
}

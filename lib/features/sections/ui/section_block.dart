import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'section_editor.dart';

enum _SectionAction { edit, move, duplicate, archive, unarchive, delete }

/// Раздел в списке проекта: стрелка свернуть, название, число задач и меню
/// «⋯» — Редактировать, Перенести в…, Дублировать, Архивировать, Удалить.
/// Архивный раздел (виден при «Выполненные задачи») — серым, в меню «Вернуть
/// из архива» и «Удалить» (help «Introduction to sections»).
/// Задачи раздела выводит список задач (коммит 2 M2.2).
class SectionBlock extends ConsumerStatefulWidget {
  const SectionBlock({
    super.key,
    required this.section,
    required this.count,
    this.readOnly = false,
  });

  final Section section;
  final int count;

  /// Проект в архиве: раздел только сворачивается, без правки и меню
  /// (допущение О-24).
  final bool readOnly;

  @override
  ConsumerState<SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends ConsumerState<SectionBlock> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final s = widget.section;
    final commands = ref.read(sectionCommandsProvider);
    if (_editing) {
      return SectionEditor(
        initial: s.name,
        submitLabel: l10n.actionSave,
        onSubmit: (name) async {
          await commands.rename(s.id, name);
          if (mounted) setState(() => _editing = false);
        },
        onCancel: () => setState(() => _editing = false),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      height: 40,
      child: Row(
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: palette.textSecondary,
            icon: Icon(s.isCollapsed ? Icons.chevron_right : Icons.expand_more),
            onPressed: () => runCommand(
              context,
              () => commands.setCollapsed(s.id, !s.isCollapsed),
            ),
          ),
          // Название и счётчик занимают всё место до меню: меню — у правого края.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: widget.readOnly || s.isArchived
                        ? null
                        : () => setState(() => _editing = true),
                    child: Text(
                      s.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: s.isArchived
                            ? palette.textSecondary
                            : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.count > 0)
                  Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.readOnly)
            PopupMenuButton<_SectionAction>(
              tooltip: l10n.moreActions,
              iconSize: 20,
              icon: const Icon(Icons.more_horiz),
              onSelected: (a) => _run(context, a),
              itemBuilder: (context) => [
                if (s.isArchived)
                  PopupMenuItem(
                    value: _SectionAction.unarchive,
                    child: Text(l10n.actionUnarchive),
                  )
                else ...[
                  PopupMenuItem(
                    value: _SectionAction.edit,
                    child: Text(l10n.actionEdit),
                  ),
                  PopupMenuItem(
                    value: _SectionAction.move,
                    child: Text(l10n.actionMoveTo),
                  ),
                  PopupMenuItem(
                    value: _SectionAction.duplicate,
                    child: Text(l10n.actionDuplicate),
                  ),
                  PopupMenuItem(
                    value: _SectionAction.archive,
                    child: Text(l10n.actionArchive),
                  ),
                ],
                PopupMenuItem(
                  value: _SectionAction.delete,
                  child: Text(l10n.actionDelete),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context, _SectionAction action) async {
    final l10n = AppLocalizations.of(context);
    final commands = ref.read(sectionCommandsProvider);
    final s = widget.section;
    switch (action) {
      case _SectionAction.edit:
        setState(() => _editing = true);
      case _SectionAction.move:
        final target = await _pickProject(context, ref, s);
        if (target == null || !context.mounted) return;
        await runCommand(context, () => commands.moveToProject(s.id, target));
      case _SectionAction.duplicate:
        await runCommand(
          context,
          () => commands.duplicate(s.id, name: l10n.copyOf(s.name)),
        );
      case _SectionAction.archive:
        final ok = await confirmAction(
          context,
          title: l10n.archiveSectionTitle,
          body: l10n.archiveSectionBody(s.name),
          action: l10n.actionArchive,
        );
        if (!ok || !context.mounted) return;
        await runCommand(context, () => commands.archive(s.id));
      case _SectionAction.unarchive:
        await runCommand(context, () => commands.unarchive(s.id));
      case _SectionAction.delete:
        final ok = await confirmAction(
          context,
          title: l10n.deleteSectionTitle,
          body: l10n.deleteSectionBody(s.name),
          action: l10n.actionDelete,
          danger: true,
        );
        if (!ok || !context.mounted) return;
        await runCommand(context, () => commands.delete(s.id));
    }
  }
}

/// Выбор проекта для «Перенести в…»: «Входящие» и активные проекты, кроме
/// текущего.
Future<String?> _pickProject(
  BuildContext context,
  WidgetRef ref,
  Section section,
) {
  final l10n = AppLocalizations.of(context);
  final Workspace? ws = ref.read(workspaceProvider).value;
  if (ws == null) return Future.value();
  final inbox = ws.inbox;
  final current = section.projectId ?? inbox?.id;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.moveSectionTitle),
      children: [
        if (inbox != null && inbox.id != current)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, inbox.id),
            child: Text(l10n.inbox),
          ),
        for (final item in ws.projectTree(expandCollapsed: true))
          if (item.value.id != current)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.value.id),
              child: Row(
                children: [
                  SizedBox(width: item.depth * 16.0),
                  ProjectHash(color: item.value.color, size: 16),
                  Flexible(
                    child: Text(
                      item.value.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

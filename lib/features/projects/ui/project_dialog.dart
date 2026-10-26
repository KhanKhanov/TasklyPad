import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// Диалог «Добавить проект» / «Редактировать проект»: название, цвет,
/// родитель, избранное. Вид (доска, календарь) — M8.
Future<void> showProjectDialog(
  BuildContext context, {
  Project? project,
  String? parentId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ProjectDialog(project: project, parentId: parentId),
);

class _ProjectDialog extends ConsumerStatefulWidget {
  const _ProjectDialog({this.project, this.parentId});

  final Project? project;
  final String? parentId;

  @override
  ConsumerState<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends ConsumerState<_ProjectDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.project?.name ?? '',
  );
  late String _color = widget.project?.color ?? 'charcoal';
  late String? _parent = widget.project?.parentId ?? widget.parentId;
  late bool _favorite = widget.project?.isFavorite ?? false;
  String? _error;
  bool _busy = false;

  bool get _editing => widget.project != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Проекты, под которые можно вложить: не «Входящие», не сам проект и не
  /// его потомки, и с запасом глубины (до 3 уровней).
  List<Project> _parents(Workspace ws) {
    final self = widget.project;
    final excluded = self == null
        ? const <String>{}
        : ws.projectSubtree(self.id).toSet();
    final height = self == null ? 1 : ws.projectHeight(self.id);
    return [
      for (final item in ws.projectTree(expandCollapsed: true))
        if (!excluded.contains(item.value.id) &&
            ws.projectDepth(item.value.id) + height <= Limits.projectLevels)
          item.value,
    ];
  }

  Future<void> _save() async {
    if (_busy) return; // повторный Enter или клик, пока идёт запись
    setState(() => _busy = true);
    final commands = ref.read(projectCommandsProvider);
    final l10n = AppLocalizations.of(context);
    final project = widget.project;
    try {
      if (project == null) {
        await commands.add(
          name: _name.text,
          color: _color,
          parentId: _parent,
          isFavorite: _favorite,
        );
      } else {
        // Пишутся только поля, изменённые в диалоге, — сравнение со значениями
        // при открытии. Иначе поле, которое не трогали, ушло бы старым
        // значением из снимка и по LWW затёрло бы правку, пришедшую с другого
        // устройства, пока диалог был открыт.
        if (_name.text.trim() != project.name) {
          await commands.rename(project.id, _name.text);
        }
        if (_color != project.color) {
          await commands.setColor(project.id, _color);
        }
        if (_favorite != project.isFavorite) {
          await commands.setFavorite(project.id, _favorite);
        }
        if (_parent != project.parentId) {
          await commands.move(project.id, parentId: _parent);
        }
      }
      if (mounted) Navigator.pop(context);
    } on CommandRejected catch (e) {
      if (mounted) {
        setState(() {
          _error = rejectMessage(l10n, e.reason);
          _busy = false;
        });
      }
    } on Exception catch (e, stackTrace) {
      logCommandError(e, stackTrace);
      if (mounted) {
        setState(() {
          _error = l10n.actionFailed('$e');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ws = ref.watch(workspaceProvider).value;
    final parents = ws == null ? const <Project>[] : _parents(ws);
    return AlertDialog(
      title: Text(_editing ? l10n.editProject : l10n.addProject),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _color,
              decoration: InputDecoration(labelText: l10n.fieldColor),
              items: [
                for (final key in projectColors.keys)
                  DropdownMenuItem(
                    value: key,
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: projectColor(key)),
                        const SizedBox(width: 10),
                        Text(colorName(l10n, key)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _color = v ?? _color),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: parents.any((p) => p.id == _parent)
                  ? _parent
                  : null,
              decoration: InputDecoration(labelText: l10n.fieldParent),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noParent)),
                for (final p in parents)
                  DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        ProjectHash(color: p.color, size: 16),
                        Flexible(
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _parent = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fieldFavorite),
              value: _favorite,
              onChanged: (v) => setState(() => _favorite = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _busy || _name.text.trim().isEmpty ? null : _save,
            child: Text(_editing ? l10n.actionSave : l10n.actionAdd),
          ),
        ),
      ],
    );
  }
}

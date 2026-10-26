import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// Диалог «Добавить метку» / «Изменить метку», как в Todoist (help
/// «Introduction to labels»): название и цвет. Избранное — из меню метки.
Future<void> showLabelDialog(BuildContext context, {Label? label}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _LabelDialog(label: label),
    );

class _LabelDialog extends ConsumerStatefulWidget {
  const _LabelDialog({this.label});

  final Label? label;

  @override
  ConsumerState<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends ConsumerState<_LabelDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.label?.name ?? '',
  );
  late String _color = widget.label?.color ?? 'charcoal';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return; // повторный Enter или клик, пока идёт запись
    setState(() => _busy = true);
    final commands = ref.read(labelCommandsProvider);
    final l10n = AppLocalizations.of(context);
    final label = widget.label;
    try {
      if (label == null) {
        await commands.add(name: _name.text, color: _color);
      } else {
        // Только изменённые поля: нетронутое поле со старым значением
        // затёрло бы правку, пришедшую с другого устройства.
        await commands.edit(
          label.id,
          name: _name.text.trim() != label.name ? _name.text : null,
          color: _color != label.color ? _color : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } on CommandRejected catch (e) {
      if (mounted) setState(() => _error = rejectMessage(l10n, e.reason));
    } on Exception catch (e, stackTrace) {
      logCommandError(e, stackTrace);
      if (mounted) setState(() => _error = l10n.actionFailed('$e'));
    } finally {
      // И при ошибке программы кнопка не остаётся заблокированной.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.label != null;
    return AlertDialog(
      title: Text(editing ? l10n.editLabel : l10n.addLabel),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
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
            child: Text(editing ? l10n.actionSave : l10n.actionAdd),
          ),
        ),
      ],
    );
  }
}

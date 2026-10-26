import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// Встроенный редактор «Добавить задачу», как в Todoist: название и
/// описание, Enter — добавить и остаться в редакторе для следующей задачи,
/// Esc — закрыть. Разбор дат и токенов в названии — M3 (Quick Add).
class AddTaskEditor extends ConsumerStatefulWidget {
  const AddTaskEditor({
    super.key,
    required this.projectId,
    this.sectionId,
    this.parentId,
    this.atTop = false,
    required this.onClose,
  });

  final String projectId;
  final String? sectionId;
  final String? parentId;
  final bool atTop;
  final VoidCallback onClose;

  @override
  ConsumerState<AddTaskEditor> createState() => _AddTaskEditorState();
}

class _AddTaskEditorState extends ConsumerState<AddTaskEditor> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Не `autofocus`: он не срабатывает, если фокус уже у экрана (хоткеи).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(taskCommandsProvider)
          .add(
            content: _name.text,
            description: _description.text.trim(),
            projectId: widget.parentId == null ? widget.projectId : null,
            sectionId: widget.parentId == null ? widget.sectionId : null,
            parentId: widget.parentId,
            atTop: widget.atTop,
          );
      if (!mounted) return;
      _name.clear();
      _description.clear();
      _nameFocus.requestFocus();
    } on CommandRejected catch (e) {
      if (mounted) setState(() => _error = rejectMessage(l10n, e.reason));
    } on Exception catch (e, stackTrace) {
      logCommandError(e, stackTrace);
      if (mounted) setState(() => _error = l10n.actionFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        decoration: BoxDecoration(
          border: Border.all(color: palette.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              focusNode: _nameFocus,
              decoration: InputDecoration(
                hintText: l10n.taskNameHint,
                border: InputBorder.none,
                errorText: _error,
              ),
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            TextField(
              controller: _description,
              decoration: InputDecoration(
                hintText: l10n.descriptionHint,
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: _name,
                  builder: (context, _) => FilledButton(
                    onPressed: _busy || _name.text.trim().isEmpty
                        ? null
                        : _submit,
                    child: Text(l10n.addTask),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «+ Добавить задачу» в конце списка; по нажатию — редактор.
class AddTaskButton extends StatelessWidget {
  const AddTaskButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add, color: palette.accent, size: 18),
        label: Text(
          label ?? AppLocalizations.of(context).addTask,
          style: TextStyle(color: palette.textSecondary),
        ),
      ),
    );
  }
}

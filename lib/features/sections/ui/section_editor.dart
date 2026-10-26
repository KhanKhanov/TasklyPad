import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// Встроенный редактор названия раздела, как в Todoist: поле и кнопки
/// «Добавить раздел» / «Сохранить» и «Отмена»; Enter — сохранить, Esc —
/// отмена. Отказ правилами показывается под полем.
class SectionEditor extends StatefulWidget {
  const SectionEditor({
    super.key,
    this.initial = '',
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
  });

  final String initial;
  final String submitLabel;
  final Future<void> Function(String name) onSubmit;
  final VoidCallback onCancel;

  @override
  State<SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<SectionEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Не `autofocus`: он не срабатывает, если фокус уже у экрана (хоткеи).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Повторный Enter или клик, пока идёт запись, создал бы второй раздел.
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await widget.onSubmit(_name.text);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              focusNode: _focus,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: l10n.sectionNameHint,
                errorText: _error,
                border: const OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
              style: TextStyle(color: palette.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ListenableBuilder(
                  listenable: _name,
                  builder: (context, _) => FilledButton(
                    onPressed: _busy || _name.text.trim().isEmpty
                        ? null
                        : _submit,
                    child: Text(widget.submitLabel),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(l10n.actionCancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

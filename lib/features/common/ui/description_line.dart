import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import 'markdown_block.dart';
import 'markdown_inline.dart';
import 'markdown_keys.dart';
import 'text_limit.dart';
import 'ui_kit.dart';

/// Описание под названием проекта или фильтра (help «Introduction to
/// projects», «Introduction to filters»): одна строка; при наведении —
/// целиком на месте, нажатие — редактор на месте с «Сохранить» и «Отмена»
/// (решение 2А «Часть M4.11» plans/m4). Без описания — [placeholder]. При
/// [readOnly] — только текст. Markdown вне редактора отрисован, в редакторе —
/// исходный текст (решение 7А плана M4).
class DescriptionLine extends StatefulWidget {
  const DescriptionLine({
    super.key,
    required this.text,
    required this.readOnly,
    required this.placeholder,
    required this.onSave,
  });

  final String text;
  final bool readOnly;
  final String placeholder;

  /// Запись нового описания; отказ (`CommandRejected`) показывается тостом,
  /// и редактор остаётся открытым.
  final Future<void> Function(String text) onSave;

  @override
  State<DescriptionLine> createState() => _DescriptionLineState();
}

class _DescriptionLineState extends State<DescriptionLine> {
  TextEditingController? _editor;

  /// Фокус редактора — для панели форматирования.
  final FocusNode _editorFocus = FocusNode();
  bool _hover = false;

  /// Описание на момент открытия редактора: с ним сравнивается сохраняемое.
  String _initial = '';

  @override
  void dispose() {
    _editor?.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    _initial = widget.text;
    _editor = TextEditingController(text: _initial);
    // MouseRegion уходит вместе со строкой — выход мыши не придёт.
    _hover = false;
  });

  void _close() {
    final editor = _editor;
    setState(() => _editor = null);
    // Поле с этим контроллером ещё в дереве до конца кадра: освободить сразу —
    // значит, что поле обратится к освобождённому контроллеру.
    WidgetsBinding.instance.addPostFrameCallback((_) => editor?.dispose());
  }

  Future<void> _save() async {
    final text = _editor?.text ?? '';
    // Без изменений — без записи. Сравнение со значением при открытии, а не
    // с текущим: иначе правка, пришедшая с другого устройства, пока редактор
    // был открыт, отличалась бы от текста редактора, и старое значение
    // затёрло бы её по LWW.
    // В том виде, в каком хранит команда: описание с переводом строки в конце
    // иначе записалось бы снова без правки, а пробел в пустом — пустым.
    if (storedDescription(text) != _initial) {
      final saved = await runGuarded(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context),
        () => widget.onSave(text),
      );
      // Отказ — редактор остаётся открытым с набранным текстом.
      if (!saved) return;
    }
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    if (editor != null) return _editorView(context, editor);
    final palette = AppPalette.of(context);
    final text = widget.text;
    if (text.isEmpty && widget.readOnly) return const SizedBox.shrink();
    final style = TextStyle(color: palette.textSecondary, fontSize: 14);
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.readOnly ? null : _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: text.isEmpty
                ? Text(widget.placeholder, style: style)
                // Markdown отрисован (help «Introduction to projects»:
                // описание форматируется); одной строкой — без знаков блоков.
                : _hover
                ? MarkdownBlock(text, style: style)
                : MarkdownInline(
                    descriptionLines(text).join('\n'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _editorView(BuildContext context, TextEditingController editor) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MarkdownKeys(
            controller: editor,
            focusNode: _editorFocus,
            blocks: true,
            max: Limits.description,
            child: TextField(
              controller: editor,
              focusNode: _editorFocus,
              autofocus: true,
              minLines: 2,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              inputFormatters: const [TextLimit(Limits.description)],
              decoration: InputDecoration(hintText: l10n.fieldDescription),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: _close, child: Text(l10n.actionCancel)),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/text_limit.dart';
import '../../common/ui/ui_kit.dart';

/// Описание под названием проекта (help «Introduction to projects»): одна
/// строка; при наведении — целиком на месте, нажатие — редактор на месте с
/// «Сохранить» и «Отмена» (решение 2А «Часть M4.11» plans/m4). Без описания —
/// «Добавить описание». У проекта в архиве — только текст.
class ProjectDescription extends ConsumerStatefulWidget {
  const ProjectDescription({
    super.key,
    required this.project,
    required this.readOnly,
  });

  final Project project;
  final bool readOnly;

  @override
  ConsumerState<ProjectDescription> createState() => _ProjectDescriptionState();
}

class _ProjectDescriptionState extends ConsumerState<ProjectDescription> {
  TextEditingController? _editor;
  bool _hover = false;

  /// Описание на момент открытия редактора: с ним сравнивается сохраняемое.
  String _initial = '';

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    _initial = widget.project.description;
    _editor = TextEditingController(text: _initial);
    // MouseRegion уходит вместе со строкой — выход мыши не придёт.
    _hover = false;
  });

  void _close() {
    final editor = _editor;
    setState(() => _editor = null);
    editor?.dispose();
  }

  Future<void> _save() async {
    final text = _editor?.text ?? '';
    // Без изменений — без записи. Сравнение со значением при открытии, а не
    // с текущим: иначе правка, пришедшая с другого устройства, пока редактор
    // был открыт, отличалась бы от текста редактора, и старое значение
    // затёрло бы её по LWW.
    if (text.trim() != _initial) {
      final saved = await runGuarded(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context),
        () => ref
            .read(projectCommandsProvider)
            .setDescription(widget.project.id, text),
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
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = widget.project.description;
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
                ? Text(l10n.addProjectDescription, style: style)
                : Text(
                    text,
                    maxLines: _hover ? null : 1,
                    overflow: _hover ? null : TextOverflow.ellipsis,
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
          TextField(
            controller: editor,
            autofocus: true,
            minLines: 2,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            inputFormatters: const [TextLimit(Limits.description)],
            decoration: InputDecoration(hintText: l10n.fieldDescription),
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

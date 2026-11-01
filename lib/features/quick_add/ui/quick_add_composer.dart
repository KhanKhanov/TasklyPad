import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../logic/quick_add_draft.dart';
import '../state/quick_add_controller.dart';
import 'paste_lines_dialog.dart';
import 'quick_add_chips.dart';
import 'quick_add_field.dart';

/// Редактор быстрого добавления — один на окно `q` и встроенные «Добавить
/// задачу» и «Добавить подзадачу» (решение 6А «Ход M3.6»): название с
/// разбором, описание, чипы, проект, «Отмена» и «Добавить задачу».
///
/// `Enter` — добавить и остаться для следующей задачи ([onAdded] — сколько
/// добавлено), `Esc` — [onClose]. Описание в окне скрыто до «+» или `↓`
/// (help «Use Task Quick Add»), во встроенном редакторе видно сразу.
class QuickAddComposer extends ConsumerStatefulWidget {
  const QuickAddComposer({
    super.key,
    required this.defaults,
    required this.onClose,
    this.onAdded,
    this.atTop = false,
    this.descriptionOpen = true,
  });

  final QuickAddDefaults defaults;
  final VoidCallback onClose;
  final ValueChanged<int>? onAdded;
  final bool atTop;
  final bool descriptionOpen;

  @override
  ConsumerState<QuickAddComposer> createState() => _QuickAddComposerState();
}

class _QuickAddComposerState extends ConsumerState<QuickAddComposer> {
  late final QuickAddController _name = QuickAddController(
    defaults: widget.defaults,
  );
  final TextEditingController _description = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  late bool _showDescription = widget.descriptionOpen;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Не `autofocus`: он не срабатывает, если фокус уже у экрана (хоткеи).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
    _name.addListener(_clearError);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _openDescription() {
    setState(() => _showDescription = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _descriptionFocus.requestFocus();
    });
  }

  /// Описание поля и описание после `//` в названии — оба, через строку.
  TaskDraft _withDescription(TaskDraft d) {
    final text = [
      _description.text.trim(),
      d.description,
    ].where((s) => s.isNotEmpty).join('\n');
    return TaskDraft(
      title: d.title,
      description: text,
      projectId: d.projectId,
      newProject: d.newProject,
      sectionId: d.sectionId,
      parentId: d.parentId,
      labelIds: d.labelIds,
      newLabels: d.newLabels,
      priority: d.priority,
      due: d.due,
      deadline: d.deadline,
      duration: d.duration,
    );
  }

  bool get _canAdd => !_busy && (_name.draft?.title.trim().isNotEmpty ?? false);

  Future<void> _submit([List<TaskDraft>? lines]) async {
    if (_busy) return;
    _name.refresh();
    final draft = _name.draft;
    final drafts =
        lines ?? [if (draft != null && _canAdd) _withDescription(draft)];
    if (drafts.isEmpty) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(quickAddCommandsProvider).add(drafts, atTop: widget.atTop);
      if (!mounted) return;
      _name.reset();
      // Описание окна вставленным строкам не передаётся — оно остаётся.
      if (lines == null) _description.clear();
      _nameFocus.requestFocus();
      widget.onAdded?.call(drafts.length);
    } on CommandRejected catch (e) {
      if (mounted) setState(() => _error = rejectMessage(l10n, e.reason));
    } on Exception catch (e, stackTrace) {
      logCommandError(e, stackTrace);
      if (mounted) setState(() => _error = l10n.actionFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Help «Add or manage multiple tasks»: «Добавить X задач?».
  Future<void> _onPasteLines(
    List<String> lines,
    TextEditingValue joined,
  ) async {
    final choice = await confirmPasteLines(context, lines.length);
    if (!mounted) return;
    switch (choice) {
      case PasteChoice.one:
        _name.value = joined;
      case PasteChoice.all:
        await _submit(_name.draftsForLines(lines));
      case null:
    }
    _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ws = ref.watch(workspaceProvider).value;
    if (ws != null) {
      _name.configure(
        ws: ws,
        clock: ref.watch(clockProvider),
        lang: Localizations.localeOf(context).languageCode,
        smartDates: ref.watch(smartDateRecognitionProvider).value ?? true,
        inboxNames: {l10n.inbox},
        defaults: widget.defaults,
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QuickAddField(
                  controller: _name,
                  focusNode: _nameFocus,
                  errorText: _error,
                  onSubmit: _submit,
                  onPasteLines: _onPasteLines,
                  onArrowDown: _openDescription,
                ),
              ),
              if (!_showDescription)
                IconButton(
                  tooltip: l10n.quickAddDescription,
                  icon: Icon(Icons.add, color: palette.textSecondary),
                  onPressed: _openDescription,
                ),
            ],
          ),
          if (_showDescription)
            TextField(
              controller: _description,
              focusNode: _descriptionFocus,
              decoration: InputDecoration(
                hintText: l10n.descriptionHint,
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
              onSubmitted: (_) => _submit(),
            ),
          const SizedBox(height: 8),
          if (ws != null)
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => QuickAddChips(controller: _name, ws: ws),
            ),
          Divider(color: palette.divider, height: 20),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => Row(
              children: [
                // Кнопка проекта берёт всё место до «Отмена»: при `Spacer`
                // рядом ей доставалась половина, и имя обрезалось.
                Expanded(
                  child: ws != null && widget.defaults.parentId == null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: QuickAddProjectButton(
                            controller: _name,
                            ws: ws,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                TextButton(
                  onPressed: widget.onClose,
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canAdd ? _submit : null,
                  child: Text(l10n.addTask),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

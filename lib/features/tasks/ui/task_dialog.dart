import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../state/title_date_controller.dart';
import 'task_dialog_layout.dart';
import 'task_dialog_top_bar.dart';
import 'task_fields.dart';
import 'task_subtasks.dart';
import 'task_title_field.dart';
import 'task_row_parts.dart';

/// Панель задачи, как в Todoist: слева путь «проект › раздел», название,
/// описание и подзадачи; справа — поля ([TaskFields]); меню — Дублировать,
/// Удалить. Задача удалена (в том числе на другом устройстве) — окно
/// закрывается.
class TaskDialog extends ConsumerStatefulWidget {
  const TaskDialog({
    super.key,
    required this.taskId,
    this.onPrevious,
    this.onNext,
  });

  final String taskId;

  /// Соседние задачи списка ([TaskPanel]); `null` — соседа нет.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  ConsumerState<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<TaskDialog> {
  late final TitleDateController _content = TitleDateController(
    clock: ref.read(clockProvider),
  );
  final TextEditingController _description = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  bool _closing = false;

  // Значения, которые сейчас стоят в полях из базы. Сохраняем, только если
  // пользователь изменил текст относительно них, — а не относительно базы:
  // пока курсор в поле, правка с другого устройства в поле не подставляется,
  // и сравнение с базой затёрло бы её старым текстом.
  String _contentBase = '';
  String _descriptionBase = '';

  @override
  void initState() {
    super.initState();
    _contentFocus.addListener(() {
      if (!_contentFocus.hasFocus) _saveContent();
    });
    _descriptionFocus.addListener(() {
      if (!_descriptionFocus.hasFocus) _saveDescription();
    });
  }

  @override
  void dispose() {
    _content.dispose();
    _description.dispose();
    _contentFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Task? _task() => ref.read(workspaceProvider).value?.task(widget.taskId);

  /// Тосты — в [ScaffoldMessenger] панели (`TaskPanel`): он переживает
  /// переход к соседней задаче, и сбой сохранения прежней виден в новом окне.
  Future<bool> _write(Future<void> Function() action) => runGuarded(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
    action,
  );

  /// Название; набранная в нём дата — новый срок той же правкой (решение 1А
  /// конца M3). Название из одной даты — пустое: вернётся прежнее.
  ///
  /// Enter сначала снимает фокус, потом вызывает `onSubmitted` — запись того
  /// же текста, пока первая идёт, пропускается ([_savingText]).
  Future<void> _saveContent() async {
    _content.refresh();
    final date = _content.parsed;
    if (date == null) return _saveName();
    final task = _task();
    final title = date.title.trim();
    if (task == null || title.isEmpty) return _resync();
    final submitted = _content.text;
    if (submitted == _savingText) return;
    _savingText = submitted;
    final base = _contentBase;
    _contentBase = title;
    try {
      final ok = await _write(
        () => ref
            .read(taskCommandsProvider)
            .renameWithDue(task.id, title, date.due),
      );
      if (!ok) _contentBase = base;
      // Окно закрыто или перешло к соседней задаче, пока шла запись, или в
      // поле уже набирают дальше — поле не трогаем.
      if (!mounted || _content.text != submitted) return;
      ok ? _content.reset(title) : _resync();
    } finally {
      _savingText = null;
    }
  }

  /// Текст названия с датой, который сейчас записывается.
  String? _savingText;

  Future<void> _saveName() => _save(
    _content.text.trim(),
    _contentBase,
    (v) => _contentBase = v,
    (id, text) => ref.read(taskCommandsProvider).rename(id, text),
    // Пустое название сохранить нельзя, как в Todoist: вернётся прежнее.
    allowEmpty: false,
  );

  Future<void> _saveDescription() => _save(
    _description.text,
    _descriptionBase,
    (v) => _descriptionBase = v,
    (id, text) => ref.read(taskCommandsProvider).setDescription(id, text),
    allowEmpty: true,
  );

  /// Записать поле, если [text] изменён относительно значения из базы
  /// [base]; не изменён, пуст или запись не прошла — поле получит значение
  /// из базы.
  Future<void> _save(
    String text,
    String base,
    void Function(String) setBase,
    Future<void> Function(String id, String text) write, {
    required bool allowEmpty,
  }) async {
    final task = _task();
    if (task == null) return;
    if (text == base || (text.isEmpty && !allowEmpty)) return _resync();
    setBase(text);
    if (!await _write(() => write(task.id, text))) {
      setBase(base);
      _resync();
    }
  }

  /// Перестроить окно, чтобы [_sync] подставил в поле значение из базы:
  /// правку с другого устройства, пришедшую, пока курсор был в поле.
  void _resync() {
    if (mounted) setState(() {});
  }

  /// Подставить значения из базы, пока поле не в работе: правка с другого
  /// устройства видна сразу, а набираемый текст не перебивается.
  void _sync(Task task) {
    if (!_contentFocus.hasFocus) {
      _contentBase = task.content;
      if (_content.text != task.content) _content.reset(task.content);
    }
    if (!_descriptionFocus.hasFocus) {
      _descriptionBase = task.description;
      if (_description.text != task.description) {
        _description.text = task.description;
      }
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (context, ws) {
      final task = ws.task(widget.taskId);
      if (task == null) {
        if (!_closing) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
        return const SizedBox.shrink();
      }
      _content.configure(
        lang: Localizations.localeOf(context).languageCode,
        smartDates: ref.watch(smartDateRecognitionProvider).value ?? true,
      );
      _sync(task);
      // Проект в архиве — только просмотр (допущение О-24).
      final readOnly = ws.isProjectArchived(ws.rootProjectOf(task.id));
      final top = TaskDialogTopBar(
        task: task,
        ws: ws,
        readOnly: readOnly,
        onPrevious: widget.onPrevious,
        onNext: widget.onNext,
      );
      return TaskDialogLayout(
        top: top,
        main: _main(context, ws, task, readOnly),
        fields: TaskFields(task: task, ws: ws, readOnly: readOnly),
      );
    },
  );

  /// Левая часть: название, описание, подзадачи.
  List<Widget> _main(
    BuildContext context,
    Workspace ws,
    Task task,
    bool readOnly,
  ) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return [
      Padding(
        // Слева 0: подзадачам нужно поле под ручку перетаскивания, остальное
        // сдвинуто на 16 само.
        padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskCheckCircle(task: task, enabled: !readOnly),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TaskTitleField(
                      controller: _content,
                      focusNode: _contentFocus,
                      readOnly: readOnly,
                      completed: task.isCompleted,
                      onSubmitted: _saveContent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: TextField(
                controller: _description,
                focusNode: _descriptionFocus,
                readOnly: readOnly,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: l10n.descriptionHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            TaskSubtasks(task: task, ws: ws, readOnly: readOnly),
          ],
        ),
      ),
    ];
  }
}

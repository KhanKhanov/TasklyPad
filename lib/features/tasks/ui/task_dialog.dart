import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/ui/app_shell.dart';
import 'task_dialog_top_bar.dart';
import 'task_fields.dart';
import 'task_subtasks.dart';
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
  final TextEditingController _content = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  bool _closing = false;

  // Значения из базы, подставленные в поля. Сравниваем с ними, а не с базой:
  // иначе чужая правка, пришедшая при курсоре в поле, затёрлась бы.
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

  Future<void> _saveContent() => _save(
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

  /// Перестроить окно: [_sync] подставит правку, пришедшую при курсоре в поле.
  void _resync() {
    if (mounted) setState(() {});
  }

  /// Подставить значения из базы, пока поле не в работе: правка с другого
  /// устройства видна сразу, а набираемый текст не перебивается.
  void _sync(Task task) {
    if (!_contentFocus.hasFocus) {
      _contentBase = task.content;
      if (_content.text != task.content) _content.text = task.content;
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
      final fields = TaskFields(task: task, ws: ws, readOnly: readOnly);
      // Свой Scaffold: тосты внутри окна, а не под его затемнением.
      Widget toasts(Widget child) =>
          Scaffold(backgroundColor: Colors.transparent, body: child);
      // Узкий экран — на весь экран, поля под подзадачами; широкий — справа.
      if (MediaQuery.sizeOf(context).width < wideLayoutWidth) {
        return Dialog.fullscreen(
          child: toasts(
            SafeArea(
              child: Column(
                children: [
                  top,
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        ..._main(context, ws, task, readOnly),
                        const Divider(height: 1),
                        fields,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 640),
          child: toasts(
            Column(
              children: [
                top,
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: _main(context, ws, task, readOnly),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 280,
                        child: SingleChildScrollView(child: fields),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskCheckCircle(task: task, enabled: !readOnly),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _content,
                    focusNode: _contentFocus,
                    readOnly: readOnly,
                    maxLines: null,
                    // Название — одна строка, как в Todoist: Enter сохраняет,
                    // вставленный перевод строки становится пробелом. Длинное
                    // название переносится только на экране.
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                        RegExp(r'[\r\n]+'),
                        replacementString: ' ',
                      ),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    onSubmitted: (_) => _saveContent(),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 34),
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

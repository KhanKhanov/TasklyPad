import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';

// Пункты меню строки задачи (showTaskRowMenu в task_row_menu.dart): каждый
// показывает задачу такой, какая она сейчас.

/// Действие над задачей из меню: правка, после которой меню остаётся.
typedef TaskMenuAct = Future<void> Function(BuildContext, WidgetRef, Task);

/// Закрыть меню, где стоит [context]: текущее — с анимацией, а под окном
/// (метки, перенос, планировщик) — сразу. Уже закрытое — ничего.
void closeTaskMenu(BuildContext context) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  if (route.isCurrent) {
    Navigator.of(context).pop();
  } else {
    Navigator.of(context).removeRoute(route);
  }
}

/// Задача [id] сейчас; удалили — меню закрывается, даже если поверх него
/// открыто окно пункта.
Task? watchMenuTask(BuildContext context, WidgetRef ref, String id) {
  final ws = ref.watch(workspaceProvider).value;
  final task = ws?.task(id);
  if (ws != null && task == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => closeTaskMenu(context));
  }
  return task;
}

/// Пункт меню: [act] выполняется из самого меню — его окна встают поверх, а
/// закрывать ли меню, решает само действие ([closeTaskMenu]). Контекст и
/// `ref` пункта живут, пока открыто меню, даже если строка задачи уже ушла
/// из списка (срок «Завтра» в «Сегодня»).
class TaskMenuEntry extends PopupMenuEntry<void> {
  const TaskMenuEntry({
    super.key,
    required this.id,
    required this.text,
    required this.icon,
    required this.act,
  });

  final String id;
  final String text;
  final IconData icon;
  final TaskMenuAct act;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(void value) => false;

  @override
  State<TaskMenuEntry> createState() => _EntryState();
}

class _EntryState extends State<TaskMenuEntry> {
  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final task = watchMenuTask(context, ref, widget.id);
      return InkWell(
        onTap: task == null ? null : () => widget.act(context, ref, task),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            children: [
              Icon(widget.icon, size: 18),
              const SizedBox(width: 12),
              Text(widget.text),
            ],
          ),
        ),
      );
    },
  );
}

/// Раздел меню с подписью и рядом значков, как «Срок» и «Приоритет» в меню
/// задачи Todoist. Значок: иконка, подсказка, приоритет его цвета, отмечен ли
/// он фоном (текущее значение), действие.
class TaskMenuIcons extends PopupMenuEntry<void> {
  const TaskMenuIcons({
    super.key,
    required this.id,
    required this.title,
    required this.icons,
  });

  final String id;
  final String title;
  final List<(IconData, String, int?, bool, TaskMenuAct)> Function(Task task)
  icons;

  @override
  double get height => 76;

  @override
  bool represents(void value) => false;

  @override
  State<TaskMenuIcons> createState() => _IconsEntryState();
}

class _IconsEntryState extends State<TaskMenuIcons> {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final task = watchMenuTask(context, ref, widget.id);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  widget.title,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ),
              if (task != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (icon, label, priority, selected, act)
                        in widget.icons(task))
                      IconButton(
                        tooltip: label,
                        iconSize: 20,
                        // Шесть значков срока — в ширину меню.
                        visualDensity: VisualDensity.compact,
                        isSelected: selected,
                        style: IconButton.styleFrom(
                          backgroundColor: selected ? palette.selected : null,
                        ),
                        color: priority == null
                            ? palette.textSecondary
                            : palette.priority[priority - 1],
                        icon: Icon(icon),
                        onPressed: () => act(context, ref, task),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

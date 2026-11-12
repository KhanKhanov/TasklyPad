import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import 'task_drag.dart';
import 'task_row_parts.dart';

/// Образ перетаскиваемой задачи: вся строка — кружок, название и срок —
/// шириной со строку на экране (решение 5А «M4.10a» plans/m4). Если тащат
/// несколько выделенных, рядом их число. Полупрозрачный (непрозрачность
/// 60 %, уточнения пользователя 12.11.2026): сквозь него видно линию места
/// броска. Только картинка: нажатия не принимает.
class TaskDragGhost extends ConsumerWidget {
  const TaskDragGhost({super.key, required this.payload});

  final TaskDrag payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final ws = ref.watch(workspaceProvider).value;
    final task = ws?.task(payload.task.id) ?? payload.task;
    final count = payload.sources.length;
    return Opacity(
      opacity: 0.6,
      child: Material(
        color: palette.raised,
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: IgnorePointer(
          child: SizedBox(
            width: (payload.ghostWidth ?? 400).clamp(160, 1200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskCheckCircle(task: task, enabled: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ws == null
                        ? Text(plainText(task.content))
                        : TaskText(task: task, ws: ws),
                  ),
                  if (count > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: palette.accent,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

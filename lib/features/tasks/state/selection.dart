import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/workspace.dart';

part 'selection.g.dart';

/// Порядок задач вида — тот же, что у соседей панели задачи
/// (`TaskOrderScope`).
typedef TaskListOrder = List<String> Function(Workspace ws);

/// Выделенные задачи вида (решение 9 плана M4): состояние интерфейса этого
/// устройства, не синхронизируется.
@immutable
final class TaskSelectionState {
  const TaskSelectionState({
    this.ids = const [],
    this.anchor,
    this.touchMode = false,
    this.order,
  });

  /// Выделенные — в порядке выделения.
  final List<String> ids;

  /// Задача, от которой `Ctrl+Shift+клик` выделяет диапазон.
  final String? anchor;

  /// Режим выделения на телефоне («Выбрать задачи»): касание выделяет или
  /// снимает выделение (решение 2А «Ход M4.8»).
  final bool touchMode;

  /// Порядок задач вида, где выделяли: для диапазона и порядка действий.
  final TaskListOrder? order;

  /// Режим выделения: есть выделенные или включён режим касаний.
  bool get active => ids.isNotEmpty || touchMode;

  bool contains(String id) => ids.contains(id);

  /// Выделенные, которые сейчас видны в виде, в его порядке. Задача, ушедшая
  /// из вида (выполнена и скрыта, перенесена на другой день, под свёрнутым
  /// родителем, удалена или убрана в архив на другом устройстве), остаётся в
  /// [ids], но не считается и не меняется: действие над невидимой задачей —
  /// неожиданная правка, а удаление — без «Отменить».
  List<String> live(Workspace ws) {
    final view = order?.call(ws) ?? const <String>[];
    final selected = ids.toSet();
    return [
      for (final id in view)
        if (selected.contains(id) && _editable(ws, id)) id,
    ];
  }

  /// Задача есть и её можно менять (не в архивном проекте).
  static bool _editable(Workspace ws, String id) =>
      ws.task(id) != null && !ws.isProjectArchived(ws.rootProjectOf(id));
}

/// Выделение задач. Сбрасывается при смене вида (оболочка) и после действия
/// над выделенными.
@Riverpod(keepAlive: true)
class TaskSelection extends _$TaskSelection {
  @override
  TaskSelectionState build() => const TaskSelectionState();

  /// `x`, `Ctrl+клик`, `Shift+клик` или касание в режиме выделения: задача
  /// выделяется или снимается; она же — начало следующего диапазона.
  void toggle(String id, {TaskListOrder? order}) {
    final ids = state.contains(id)
        ? [
            for (final i in state.ids)
              if (i != id) i,
          ]
        : [...state.ids, id];
    state = TaskSelectionState(
      ids: ids,
      anchor: id,
      touchMode: state.touchMode,
      order: order ?? state.order,
    );
  }

  /// `Ctrl+Shift+клик`: выделить задачи от начала диапазона до [id]
  /// включительно в порядке вида (help «Add or manage multiple tasks»). Нет
  /// начала или одной из задач нет в виде — как [toggle].
  void selectRange(String id, Workspace ws, {TaskListOrder? order}) {
    final view = (order ?? state.order)?.call(ws) ?? const <String>[];
    final from = view.indexOf(state.anchor ?? '');
    final to = view.indexOf(id);
    if (from < 0 || to < 0) {
      toggle(id, order: order);
      return;
    }
    final range = view.sublist(
      from < to ? from : to,
      (from < to ? to : from) + 1,
    );
    state = TaskSelectionState(
      ids: [
        ...state.ids,
        for (final i in range)
          if (!state.contains(i)) i,
      ],
      anchor: state.anchor,
      touchMode: state.touchMode,
      order: order ?? state.order,
    );
  }

  /// «Выбрать задачи» на телефоне; [order] — порядок вида, откуда выбрали.
  void startTouchMode({TaskListOrder? order}) => state = TaskSelectionState(
    ids: state.ids,
    anchor: state.anchor,
    touchMode: true,
    order: order ?? state.order,
  );

  /// «Выделить все» в режиме выделения на телефоне (help «Add or manage
  /// multiple tasks»: «tap "Select All"»): все задачи вида, которые можно
  /// менять.
  void selectAll(Workspace ws) {
    final view = state.order?.call(ws) ?? const <String>[];
    state = TaskSelectionState(
      ids: [
        for (final id in view)
          if (TaskSelectionState._editable(ws, id)) id,
      ],
      anchor: state.anchor,
      touchMode: state.touchMode,
      order: state.order,
    );
  }

  /// `Esc`, «Снять выделение», смена вида, выполненное действие.
  void clear() {
    if (state.active || state.anchor != null) {
      state = const TaskSelectionState();
    }
  }
}

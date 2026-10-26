import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'view_options.g.dart';

/// «Просмотр → Выполненные задачи» для вида [viewId] (id проекта).
///
/// Пока локально на этом устройстве: в Todoist настройки вида синхронизируются
/// вместе с сортировкой и группировкой — это M4 (docs/OBLIGATIONS.md, О-22).
@Riverpod(keepAlive: true)
class ShowCompleted extends _$ShowCompleted {
  @override
  bool build(String viewId) => false;

  void toggle() => state = !state;
}

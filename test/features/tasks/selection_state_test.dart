import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/tasks/state/selection.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Состояние выделения (решение 9 плана M4): порядок вида, диапазон, задачи,
// ушедшие из вида, «Выделить все».
void main() {
  late AppCommands app;
  late ProviderContainer container;
  late List<String> ids;

  setUp(() async {
    app = AppCommands(await TestDevice.start());
    container = ProviderContainer();
    addTearDown(container.dispose);
    ids = [
      for (final name in ['А', 'Б', 'В', 'Г'])
        await app.tasks.add(content: name),
    ];
  });

  TaskSelection selection() => container.read(taskSelectionProvider.notifier);
  TaskSelectionState state() => container.read(taskSelectionProvider);

  /// Вид — задачи «Входящих», которые ещё не выполнены.
  List<String> view(Workspace ws) => [
    for (final t in ws.projectTasks(ws.inbox!.id))
      if (!t.isCompleted) t.id,
  ];

  test('выделенные — в порядке вида, а не кликов', () async {
    final ws = await app.read();
    selection().toggle(ids[2], order: view);
    selection().toggle(ids[0], order: view);
    expect(state().live(ws), [ids[0], ids[2]]);
  });

  test('диапазон снизу вверх — от прошлой выделенной до кликнутой '
      'включительно', () async {
    final ws = await app.read();
    selection().toggle(ids[3], order: view);
    selection().selectRange(ids[1], ws, order: view);
    expect(state().live(ws), [ids[1], ids[2], ids[3]]);
  });

  test('задача ушла из вида (выполнена, удалена, проект в архиве) — не в '
      'числе выделенных; вернулась — снова выделена', () async {
    final work = await app.projects.add(name: 'Работа');
    final archived = await app.tasks.add(content: 'Д', projectId: work);
    List<String> all(Workspace ws) => [...view(ws), archived];
    for (final id in [...ids, archived]) {
      selection().toggle(id, order: all);
    }
    await app.tasks.complete(ids[0]);
    await app.tasks.delete(ids[1]);
    await app.projects.archive(work);
    expect(state().live(await app.read()), [ids[2], ids[3]]);

    await app.tasks.uncomplete(ids[0]);
    // Возвращённая задача встаёт на прежнее место — и в выделении тоже.
    expect(state().live(await app.read()), [ids[0], ids[2], ids[3]]);
  });

  test(
    '«Выделить все» — все задачи вида; `clear` снимает и режим касаний',
    () async {
      final ws = await app.read();
      selection().startTouchMode(order: view);
      selection().selectAll(ws);
      expect(state().live(ws), ids);
      expect(state().touchMode, isTrue);

      selection().clear();
      expect(state().active, isFalse);
      expect(state().touchMode, isFalse);
    },
  );
}

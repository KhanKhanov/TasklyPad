import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// «Перенести» у блока «Просрочено» (решение 10 плана M4, M4.6).
void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  const weekly = Due(
    date: '2026-10-19',
    time: '08:00',
    tz: 'Europe/Moscow',
    string: 'каждый пн',
    lang: 'ru',
    rule: RecurrenceRule(
      rrule: ['RRULE:FREQ=WEEKLY;BYDAY=MO'],
      fromCompletion: false,
    ),
  );

  test('все задачи — на дату одним действием: время и правило остаются, у '
      'повторяющейся меняется только вхождение; «Отменить» возвращает все '
      'сроки', () async {
    final plain = await app.tasks.add(
      content: 'Отчёт',
      due: const Due(date: '2026-10-20'),
    );
    final timed = await app.tasks.add(
      content: 'Звонок',
      due: const Due(date: '2026-10-21', time: '15:30'),
    );
    final recurring = await app.tasks.add(content: 'Зарядка', due: weekly);

    final undo = await app.tasks.rescheduleOverdue([
      plain,
      timed,
      recurring,
    ], '2026-10-25');
    var ws = await app.read();
    expect(ws.task(plain)!.due, const Due(date: '2026-10-25'));
    expect(ws.task(timed)!.due, const Due(date: '2026-10-25', time: '15:30'));
    expect(ws.task(recurring)!.due, weekly.copyWith(date: '2026-10-25'));
    expect(ws.task(recurring)!.due!.isRecurring, isTrue);

    await undo();
    ws = await app.read();
    expect(ws.task(plain)!.due, const Due(date: '2026-10-20'));
    expect(ws.task(timed)!.due, const Due(date: '2026-10-21', time: '15:30'));
    expect(ws.task(recurring)!.due, weekly);
  });

  test('«Без срока» снимает срок у всех; выполненная и удалённая к этому '
      'моменту задачи не меняются', () async {
    final a = await app.tasks.add(
      content: 'А',
      due: const Due(date: '2026-10-20'),
    );
    final done = await app.tasks.add(
      content: 'Б',
      due: const Due(date: '2026-10-20'),
    );
    final gone = await app.tasks.add(
      content: 'В',
      due: const Due(date: '2026-10-20'),
    );
    await app.tasks.complete(done);
    await app.tasks.delete(gone);
    final before = (await device.ownOps()).length;

    await app.tasks.rescheduleOverdue([a, done, gone, 'нет'], null);
    final ws = await app.read();
    expect(ws.task(a)!.due, isNull);
    expect(ws.task(done)!.due, const Due(date: '2026-10-20'));
    expect((await device.ownOps()).length, before + 1);
  });

  test('задача в проекте, убранном в архив, и задача, уже перенесённая на '
      'будущее другим устройством, не меняются: правки, которой не видно, '
      'команда не пишет', () async {
    final project = await app.projects.add(name: 'Дача');
    final archived = await app.tasks.add(
      content: 'Полить',
      projectId: project,
      due: const Due(date: '2026-10-20'),
    );
    final moved = await app.tasks.add(
      content: 'Позвонить',
      due: const Due(date: '2026-10-20'),
    );
    await app.projects.archive(project);
    await app.tasks.setDue(moved, const Due(date: '2026-10-30'));

    await app.tasks.rescheduleOverdue([archived, moved], '2026-10-25');
    final ws = await app.read();
    expect(ws.task(archived)!.due, const Due(date: '2026-10-20'));
    expect(ws.task(moved)!.due, const Due(date: '2026-10-30'));
  });
}

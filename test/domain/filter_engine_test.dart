import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/domain/filter_engine.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/nlp/filter_parser.dart';

// День `created:` — по часам приложения (`AppClock.wallOf`), в том же поясе,
// что «сегодня» (`AppClock.nowWall`), а не по поясу машины теста (О-102).
// Пояса +14 и −11 выбраны так, что пояс любой машины (от −12 до +14) хотя бы
// в одном из двух случаев разошёлся бы с ожиданием.

const _inbox = Project(
  id: 'inbox',
  name: 'Входящие',
  color: 'charcoal',
  orderKey: 'a',
  isFavorite: false,
  isArchived: false,
  isInbox: true,
  viewStyle: 'list',
  isCollapsed: false,
);

Task _added(String id, DateTime at) => Task(
  id: id,
  content: id,
  description: '',
  projectId: 'inbox',
  orderKey: id,
  priority: 4,
  isCollapsed: false,
  isCompleted: false,
  addedAt: at.toIso8601String(),
);

List<String> _createdToday(Workspace ws, AppClock clock) {
  final now = clock.nowWall();
  return [
    for (final list in evaluateFilter(
      ws,
      parseFilterQuery('created: today', now: now),
      now: now,
      wallOf: clock.wallOf,
    ))
      for (final t in list.tasks) t.id,
  ];
}

void main() {
  // 13.11.2026 12:00 UTC: в поясе +14 — 14-е 02:00, в поясе −11 — 13-е 01:00.
  final instant = DateTime.utc(2026, 11, 13, 12);

  test('created: today — пояс +14: добавленная после местной полуночи — '
      'сегодня, за полчаса до неё — нет', () {
    final ws = Workspace(
      projects: const [_inbox],
      sections: const [],
      labels: const [],
      tasks: [
        // 14-е 00:30 и 13-е 23:30 по местным часам.
        _added('after_midnight', DateTime.utc(2026, 11, 13, 10, 30)),
        _added('before_midnight', DateTime.utc(2026, 11, 13, 9, 30)),
      ],
    );
    final clock = FixedClock(instant, wallOffset: const Duration(hours: 14));
    expect(_createdToday(ws, clock), ['after_midnight']);
  });

  test('created: today — пояс −11: добавленная после местной полуночи — '
      'сегодня, за полчаса до неё — нет', () {
    final ws = Workspace(
      projects: const [_inbox],
      sections: const [],
      labels: const [],
      tasks: [
        // 13-е 00:30 и 12-е 23:30 по местным часам.
        _added('after_midnight', DateTime.utc(2026, 11, 13, 11, 30)),
        _added('before_midnight', DateTime.utc(2026, 11, 13, 10, 30)),
      ],
    );
    final clock = FixedClock(instant, wallOffset: const Duration(hours: -11));
    expect(_createdToday(ws, clock), ['after_midnight']);
  });
}

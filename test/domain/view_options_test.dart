import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/view_options.dart';

// «Отображение: N» — выбранные сортировка и группировка (help «Sort or group
// tasks»; решение 1А «Ход M4.6»).
void main() {
  test('«Вручную» — выбор в «Сегодня» и «Предстоящем» (по умолчанию там '
      'умный порядок), но не в проекте, где это умолчание', () {
    for (final type in [ViewType.today, ViewType.upcoming]) {
      final view = ViewOptions(viewType: type, sorting: Sorting.manual);
      expect(view.applied, 1, reason: '$type');
    }
    const project = ViewOptions(
      viewType: ViewType.project,
      objectId: 'p',
      sorting: Sorting.manual,
    );
    expect(project.applied, 0);
    const label = ViewOptions(
      viewType: ViewType.label,
      objectId: 'l',
      sorting: Sorting.manual,
    );
    expect(label.applied, 0);
  });

  test('сортировка с направлением и группировка — по одному; «Выполненные '
      'задачи» не считаются', () {
    const view = ViewOptions(
      viewType: ViewType.today,
      grouping: Grouping.priority,
      sorting: Sorting.deadline,
      showCompletedTasks: true,
    );
    expect(view.applied, 2);
    expect(const ViewOptions(viewType: ViewType.today).applied, 0);
  });

  test('у «Предстоящего» группировка не считается — её там нет', () {
    const upcoming = ViewOptions(
      viewType: ViewType.upcoming,
      grouping: Grouping.priority,
    );
    expect(upcoming.applied, 0);
  });

  group('allowsDrag', () {
    final cases = <(ViewType, Grouping, Sorting, bool)>[
      (ViewType.project, Grouping.none, Sorting.byDefault, true),
      (ViewType.today, Grouping.none, Sorting.byDefault, true),
      (ViewType.today, Grouping.none, Sorting.manual, true),
      (ViewType.upcoming, Grouping.none, Sorting.manual, true),
      // Группировка у «Предстоящего» не действует (из импорта).
      (ViewType.upcoming, Grouping.priority, Sorting.byDefault, true),
      (ViewType.project, Grouping.priority, Sorting.byDefault, false),
      (ViewType.today, Grouping.dueDate, Sorting.byDefault, false),
      (ViewType.project, Grouping.none, Sorting.alphabetically, false),
      (ViewType.upcoming, Grouping.none, Sorting.priority, false),
      (ViewType.label, Grouping.none, Sorting.byDefault, false),
      (ViewType.filter, Grouping.none, Sorting.byDefault, false),
    ];
    for (final (type, grouping, sorting, want) in cases) {
      test('$type, $grouping, $sorting → $want', () {
        final options = ViewOptions(
          viewType: type,
          grouping: grouping,
          sorting: sorting,
        );
        expect(options.allowsDrag, want);
      });
    }
  });
}

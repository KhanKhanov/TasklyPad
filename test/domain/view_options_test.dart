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
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../tasks/logic/due_dates.dart';
import '../../tasks/state/today.dart';

part 'upcoming_day.g.dart';

/// Выбранный день «Предстоящего» `YYYY-MM-DD` — дата по умолчанию новой
/// задачи (help «Plan your week with the Upcoming view»: «click Add task to
/// create a task for that selected day»). Не синхронизируется: это место
/// просмотра, а не данные. Пока экран открыт — живёт; при уходе с экрана и
/// в полночь — снова сегодня.
@riverpod
class UpcomingDay extends _$UpcomingDay {
  @override
  String build() => isoDate(ref.watch(todayProvider));

  void select(String day) => state = day;
}

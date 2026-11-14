import '../../../domain/filter_engine.dart';
import '../../../domain/filter_query.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../nlp/filter_parser.dart';

/// Проверка задачи фильтром «Отображения» вида [options] (`filtered_by`,
/// решение 3А plans/m5) на момент [now] — стенное время устройства
/// (`AppClock.nowWall`). `null` — фильтра нет, у вида его не бывает
/// («Предстоящее») или запрос не разбирается (импорт): задачи не прячутся.
bool Function(Task)? viewFilterTest(
  Workspace ws,
  ViewOptions options, {
  required DateTime now,
}) {
  final query = options.filteredBy;
  if (!options.filterApplies || query == null || query.trim().isEmpty) {
    return null;
  }
  try {
    return filterTest(ws, parseFilterQuery(query, now: now), now: now);
  } on FilterSyntaxError {
    return null;
  }
}

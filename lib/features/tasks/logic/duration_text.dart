import '../../../domain/models.dart';
import '../../../domain/rules.dart';

// Своя длительность, набранная в поле (help «Set a task duration»: «select
// or type a duration»). Формы ввода в help не описаны — допущение решения 13А
// plans/m4: `90` (минуты), `1ч 30м`, `1h30m`, `2 ч`, `45 мин`, `1:30`.

final RegExp _clock = RegExp(r'^(\d{1,2}):(\d{2})$');
final RegExp _units = RegExp(
  r'^(?:(\d{1,4})\s*(?:h|hr|hrs|hours?|ч|час|часа|часов)\.?)?\s*'
  r'(?:(\d{1,4})\s*(?:m|min|mins|minutes?|м|мин|минуты?|минут)\.?)?$',
  caseSensitive: false,
);

/// Минуты из набранного текста; `null` — текст не похож на длительность.
/// Диапазон не проверяется: больше суток отклоняет [checkDuration].
int? parseDurationMinutes(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (int.tryParse(t) case final minutes?) return minutes;
  if (_clock.firstMatch(t) case final m?) {
    final minutes = int.parse(m[2]!);
    if (minutes >= 60) return null;
    return int.parse(m[1]!) * 60 + minutes;
  }
  final m = _units.firstMatch(t);
  if (m == null || (m[1] == null && m[2] == null)) return null;
  return int.parse(m[1] ?? '0') * 60 + int.parse(m[2] ?? '0');
}

/// Длительность в минутах; у `day` — сутки на единицу (поле API Todoist).
int durationInMinutes(TaskDuration d) =>
    d.unit == 'day' ? d.amount * 24 * 60 : d.amount;

/// Длительность вне 1 минуты – 24 часов — [RejectReason.badDuration].
void checkDuration(TaskDuration? d) {
  if (d == null) return;
  final minutes = durationInMinutes(d);
  if (minutes < 1 || minutes > Limits.durationMinutes) {
    throw const CommandRejected(RejectReason.badDuration);
  }
}

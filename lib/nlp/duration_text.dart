// Своя длительность, набранная в поле (help «Set a task duration»: «select
// or type a duration»). Формы ввода в help не описаны — допущение решения 13А
// plans/m4: `90` (минуты), `1ч 30м`, `1h30m`, `2 ч`, `45 мин`, `1:30`.
// Примеры — test/fixtures/durations.json. Длительность в быстром добавлении
// (`for 1h`, `в течение 2ч`) разбирает quick_add.dart; диапазон у обоих —
// `Limits.durationInRange`.

final RegExp _clock = RegExp(r'^(\d{1,2}):(\d{2})$');
final RegExp _units = RegExp(
  r'^(?:(\d{1,4})\s*(?:h|hr|hrs|hours?|ч|час|часа|часов)\.?)?\s*'
  r'(?:(\d{1,4})\s*(?:m|min|mins|minutes?|м|мин|минуты?|минут)\.?)?$',
  caseSensitive: false,
);

/// Минуты из набранного текста; `null` — текст не похож на длительность.
/// Диапазон не проверяется: его проверяет `Limits.durationInRange`.
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

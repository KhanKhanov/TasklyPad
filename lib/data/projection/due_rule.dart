import '../../domain/models.dart';
import 'entity_fields.dart';

// Правило повторения в сроке задачи: одно место, где значение ключа `rule`
// из op превращается в правило. Проектор срока, снимок `Workspace` и экран
// «Конфликты» читают его одинаково.

/// Правило из значения ключа [DueKeys.rule] или `null`, если это не правило:
/// нужен непустой список строк [RuleKeys.rrule] и логическое
/// [RuleKeys.fromCompletion]. Лишние ключи (от более новой версии) не мешают.
RecurrenceRule? recurrenceRuleOf(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final (rrule, fromCompletion) = (
    value[RuleKeys.rrule],
    value[RuleKeys.fromCompletion],
  );
  if (rrule is! List<Object?> || rrule.isEmpty || fromCompletion is! bool) {
    return null;
  }
  final lines = <String>[];
  for (final line in rrule) {
    if (line is! String || line.isEmpty) return null;
    lines.add(line);
  }
  return RecurrenceRule(rrule: lines, fromCompletion: fromCompletion);
}

import 'package:freezed_annotation/freezed_annotation.dart';

import 'models.dart';

part 'conflicts.freezed.dart';

// Параллельные правки, какими их видит экран «Конфликты» (SYNC_DESIGN
// «Конфликты: решает пользователь»). Собирает их `ConflictRepository`
// (lib/sync) из журнала; здесь — только смысл, без имён полей журнала.

/// Чего касается спор.
enum ConflictEntity { task, project, section, label, taskLabel, other }

/// Поле в споре — по смыслу, а не по имени в журнале.
enum ConflictField {
  name,
  content,
  description,
  project,
  section,
  parentTask,
  parentProject,
  priority,
  due,
  deadline,
  duration,
  completed,
  color,
  favorite,
  archived,
  viewStyle,

  /// Удалено (`true`) или восстановлено, у метки задачи — снята или стоит.
  deleted,

  /// Поле, которого эта версия приложения не знает (от более новой).
  other,
}

/// Проект, раздел или задача, на которые указывает значение поля.
@freezed
abstract class ConflictRef with _$ConflictRef {
  const factory ConflictRef({
    required String id,

    /// Имя или название; `null` — этой сущности на устройстве нет.
    String? title,
    @Default(false) bool isInbox,
    @Default(false) bool isDeleted,
  }) = _ConflictRef;
}

/// Значение одного поля у одной стороны спора.
///
/// Тип [value] задаёт [field]: `String` — название, описание, цвет, вид,
/// дедлайн (`YYYY-MM-DD`); `int` — приоритет; `bool` — флаги и удаление;
/// [Due], [TaskDuration], [ConflictRef]; `null` — поле пусто. У
/// [ConflictField.other] — значение из журнала как есть.
@freezed
abstract class ConflictValue with _$ConflictValue {
  const factory ConflictValue({
    required ConflictField field,

    /// Имя поля в журнале — подпись незнакомого поля.
    required String key,
    Object? value,
  }) = _ConflictValue;
}

/// Одна сторона спора: правка одного устройства.
@freezed
abstract class ConflictSide with _$ConflictSide {
  const factory ConflictSide({
    required String nodeId,

    /// Правка этого устройства — или его прежнего id (база скопирована).
    @Default(false) bool isThisDevice,
    @Default(false) bool isFormerThisDevice,

    /// Время правки по часам её устройства, UTC.
    required DateTime at,

    /// Сторона удалила сущность (у метки задачи — сняла метку).
    required bool deletes,

    /// Что показать.
    required List<ConflictValue> values,

    /// Что записать при выборе этой стороны: поле журнала → значение.
    required Map<String, Object?> fields,

    /// Значения этой стороны действуют сейчас.
    required bool isCurrent,
  }) = _ConflictSide;
}

/// Карточка экрана «Конфликты». Правка — одна пара действий над сущностью
/// со всеми полями, которые оба действия записали (выбор целиком,
/// docs/plans/m2-core-app.md, решение 2Б к коммиту 3 M2.3); удаление — все
/// споры удаления сущности. Выбор закрывает все [conflictIds].
@freezed
abstract class ConflictCard with _$ConflictCard {
  const factory ConflictCard({
    required ConflictEntity entity,
    required String entityId,

    /// Название задачи или имя проекта, раздела, метки; `null` — пусто.
    String? title,
    @Default(false) bool isInbox,

    /// У метки задачи — название задачи ([title] — имя метки).
    String? ownerTitle,
    required bool isDelete,
    required List<String> conflictIds,

    /// Более ранняя правка — проигравшая, пока пользователь не выбрал.
    required ConflictSide older,
    required ConflictSide newer,

    /// Действующие значения, если ни одна сторона не действует целиком
    /// (поле правили после конфликта), иначе пусто.
    @Default(<ConflictValue>[]) List<ConflictValue> current,
  }) = _ConflictCard;

  const ConflictCard._();

  /// Устойчивый ключ карточки для списка.
  String get key => conflictIds.first;
}

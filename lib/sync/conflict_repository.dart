import 'package:oplog_sync/oplog_sync.dart';

import '../data/app_database.dart';
import '../data/local_meta_dao.dart';
import '../data/projection/entity_fields.dart';
import '../domain/conflicts.dart';
import '../domain/models.dart';
import 'drift_op_store.dart';

/// Открытые конфликты — для экрана «Конфликты» и уведомлений.
///
/// Живёт рядом с [DriftOpStore], а не в lib/data: значения сторон берутся из
/// журнала ops, а «разрешён ли конфликт» — из `DriftOpStore.conflicts`, чтобы
/// правило было записано в одном месте.
///
/// Конфликты по полям из [silentFields] не показываются: по текущим правилам
/// это не конфликт (записаны до того, как поле стало «молчащим»), и
/// «Пересобрать базу из журнала» их удалит.
final class ConflictRepository {
  ConflictRepository({
    required this._db,
    required this._store,
    required this._meta,
  });

  final AppDatabase _db;
  final DriftOpStore _store;
  final LocalMetaDao _meta;

  /// Поля метки задачи, одинаковые у обеих сторон (из id): показывать нечего.
  static const Set<String> _identityFields = {
    TaskLabelFields.taskId,
    TaskLabelFields.labelId,
  };

  /// Карточки сейчас и после каждого изменения конфликтов или полей.
  Stream<List<ConflictCard>> watch() => _db
      .customSelect('SELECT 1', readsFrom: {_db.conflicts, _db.fieldVersions})
      .watch()
      .asyncMap((_) => load());

  /// Открытые конфликты карточками, новые сверху.
  Future<List<ConflictCard>> load() => _db.transaction(_load);

  /// Карточки, о которых это устройство ещё не уведомляло, — и запомнить,
  /// что уведомило обо всех открытых. Решение по таблице конфликтов, а не по
  /// отчёту прохода: конфликт из перечитанного после сбоя чанка, из прохода,
  /// упавшего после применения, и из переиздания (`adopt`) в отчёт не
  /// попадает (О-9). Запоминаются только открытые: разрешённые выпадают сами.
  Future<List<ConflictCard>> takeUnnotified() => _db.transaction(() async {
    final cards = await _load();
    final notified = await _meta.notifiedConflicts();
    final open = {for (final card in cards) ...card.conflictIds};
    if (open.length != notified.length || !notified.containsAll(open)) {
      await _meta.setNotifiedConflicts(open);
    }
    return [
      for (final card in cards)
        if (card.conflictIds.any((id) => !notified.contains(id))) card,
    ];
  });

  Future<List<ConflictCard>> _load() async {
    final open = [
      for (final c in await _store.conflicts())
        if (!c.resolved && !silentFields.contains(c.field)) c,
    ];
    if (open.isEmpty) return const [];
    final opsByEntity = <String, Map<String, Op>>{};
    final groups = <String, List<(Conflict, Op, Op)>>{};
    for (final c in open) {
      final entityKey = _entityKey(c);
      final ops = opsByEntity[entityKey] ??= {
        for (final op in await _store.opsForEntity(c.entityType, c.entityId))
          op.opId: op,
      };
      final (older, newer) = (ops[c.olderOpId], ops[c.newerOpId]);
      if (older == null || newer == null) {
        // Конфликт вычисляется из журнала, а ops из него не удаляются.
        throw StateError('Нет ops конфликта ${c.id} в журнале');
      }
      // Удаление: все споры удаления сущности и спор «удалено / восстановлено»
      // — одна карточка. Правка: одна пара действий (общий HLC у полей одного
      // действия) — одна карточка.
      final key = _isDelete(c)
          ? 'delete $entityKey'
          : 'edit $entityKey ${older.hlc} ${newer.hlc}';
      (groups[key] ??= []).add((c, older, newer));
    }
    final thisNode = await _meta.nodeId();
    final former = await _meta.previousNodeIds();
    final cards = [
      for (final group in groups.values)
        _withDevices(
          await _card(group, opsByEntity[_entityKey(group.first.$1)]!),
          thisNode,
          former,
        ),
    ];
    return cards..sort((a, b) {
      final byTime = b.newer.at.compareTo(a.newer.at);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  }

  static ConflictCard _withDevices(
    ConflictCard card,
    String? thisNode,
    Set<String> former,
  ) {
    ConflictSide mark(ConflictSide side) => side.copyWith(
      isThisDevice: side.nodeId == thisNode,
      isFormerThisDevice: former.contains(side.nodeId),
    );
    return card.copyWith(older: mark(card.older), newer: mark(card.newer));
  }

  static String _entityKey(Conflict c) => '${c.entityType}/${c.entityId}';

  static bool _isDelete(Conflict c) =>
      c.kind == ConflictKind.delete || c.field == Op.deletedField;

  Future<ConflictCard> _card(
    List<(Conflict, Op, Op)> group,
    Map<String, Op> entityOps,
  ) async {
    final first = group.first.$1;
    final (type, id) = (first.entityType, first.entityId);
    final (older, newer, current) = _isDelete(first)
        ? await _deleteSides(type, id, group)
        : await _editSides(type, id, group, entityOps.values);
    final (title, ownerTitle) = await _titles(type, id);
    return ConflictCard(
      entity: _entityOf(type),
      entityId: id,
      title: title,
      ownerTitle: ownerTitle,
      isInbox: await _isInbox(type, id),
      isDelete: _isDelete(first),
      conflictIds: [for (final (c, _, _) in group) c.id]..sort(),
      older: older,
      newer: newer,
      current: older.isCurrent || newer.isCurrent ? const [] : current,
    );
  }

  /// Стороны правки. Каждая сторона записывает при выборе оба действия
  /// целиком (решения 2Б и 5А к коммиту 3 M2.3): свои поля — своими
  /// значениями, поля только другого действия — значением, которое видел её
  /// автор (`seenValue`). Так «выполнена» уходит вместе с датой выполнения
  /// (она «молчит», решение 1А), а перенос без смены раздела возвращает и
  /// раздел. Показываются поля, в которых стороны расходятся, — с
  /// действующими значениями.
  Future<_Sides> _editSides(
    String type,
    String id,
    List<(Conflict, Op, Op)> group,
    Iterable<Op> entityOps,
  ) async {
    final ops = entityOps.toList();
    final (_, olderOp, newerOp) = group.first;
    Map<String, Object?> action(Op author) => {
      for (final op in ops)
        if (op.hlc == author.hlc) op.field: op.value,
    };
    final (olderOwn, newerOwn) = (action(olderOp), action(newerOp));
    final keys = {...olderOwn.keys, ...newerOwn.keys};
    Map<String, Object?> whole(Map<String, Object?> own, Op author) => {
      for (final key in keys)
        key: own.containsKey(key) ? own[key] : seenValue(author, key, ops),
    };
    final (olderFields, newerFields) = (
      whole(olderOwn, olderOp),
      whole(newerOwn, newerOp),
    );
    final shown = [
      for (final key in keys)
        if (!silentFields.contains(key) &&
            !jsonEquals(olderFields[key], newerFields[key]))
          key,
    ];
    final current = {
      for (final key in shown) key: await _store.fieldValue(type, id, key),
    };
    Future<ConflictSide> side(
      Op author,
      Map<String, Object?> fields,
    ) async => ConflictSide(
      nodeId: author.nodeId,
      at: _time(author),
      deletes: false,
      values: await _values(type, {for (final key in shown) key: fields[key]}),
      fields: fields,
      isCurrent: shown.every((key) => jsonEquals(fields[key], current[key])),
    );

    return (
      await side(olderOp, olderFields),
      await side(newerOp, newerFields),
      await _values(type, current),
    );
  }

  /// Стороны удаления: удаление (последнее, если их несколько) и правки
  /// другой стороны (последнее значение каждого поля). Выбор пишет только
  /// `deleted`: правки на других полях уже действуют по LWW.
  Future<_Sides> _deleteSides(
    String type,
    String id,
    List<(Conflict, Op, Op)> group,
  ) async {
    final ops = {
      for (final (_, older, newer) in group) ...{
        older.opId: older,
        newer.opId: newer,
      },
    }.values.toList()..sort((a, b) => a.hlc.compareTo(b.hlc));
    final deletes = [
      for (final op in ops)
        if (op.isTombstone) op,
    ];
    final edits = [
      for (final op in ops)
        if (!op.isTombstone) op,
    ];
    if (deletes.isEmpty || edits.isEmpty) {
      throw StateError('Спор удаления $type/$id без удаления или правки');
    }
    final deleted = await _store.fieldValue(type, id, Op.deletedField) == true;
    final (deletion, edit) = (deletes.last, edits.last);
    final editFields = {
      for (final op in edits)
        if (!_identityFields.contains(op.field)) op.field: op.value,
    };
    final deleteSide = ConflictSide(
      nodeId: deletion.nodeId,
      at: _time(deletion),
      deletes: true,
      values: [await _value(type, Op.deletedField, true)],
      fields: const {Op.deletedField: true},
      isCurrent: deleted,
    );
    final editSide = ConflictSide(
      nodeId: edit.nodeId,
      at: _time(edit),
      deletes: false,
      values: await _values(type, editFields),
      fields: const {Op.deletedField: false},
      isCurrent: !deleted,
    );
    return deletion.hlc < edit.hlc
        ? (deleteSide, editSide, const <ConflictValue>[])
        : (editSide, deleteSide, const <ConflictValue>[]);
  }

  static DateTime _time(Op op) =>
      DateTime.fromMillisecondsSinceEpoch(op.hlc.wallMs, isUtc: true);

  Future<(String?, String?)> _titles(String type, String id) async {
    if (type != EntityTypes.taskLabel) return (await _title(type, id), null);
    final labelId = await _store.fieldValue(type, id, TaskLabelFields.labelId);
    final taskId = await _store.fieldValue(type, id, TaskLabelFields.taskId);
    return (
      labelId is String ? await _title(EntityTypes.label, labelId) : null,
      taskId is String ? await _title(EntityTypes.task, taskId) : null,
    );
  }

  /// Название задачи или имя проекта, раздела, метки — и удалённых тоже.
  Future<String?> _title(String type, String id) async {
    final value = await _store.fieldValue(
      type,
      id,
      type == EntityTypes.task ? TaskFields.content : ProjectFields.name,
    );
    return value is String ? value : null;
  }

  Future<bool> _isInbox(String type, String id) async =>
      type == EntityTypes.project &&
      await _store.fieldValue(type, id, ProjectFields.isInbox) == true;

  Future<ConflictRef?> _ref(String type, Object? raw) async {
    if (raw is! String) return null;
    return ConflictRef(
      id: raw,
      title: await _title(type, raw),
      isInbox: await _isInbox(type, raw),
      isDeleted: await _store.fieldValue(type, raw, Op.deletedField) == true,
    );
  }

  /// Значения полей в порядке [ConflictField] — одинаково на всех
  /// устройствах, независимо от id конфликтов.
  Future<List<ConflictValue>> _values(
    String type,
    Map<String, Object?> fields,
  ) async =>
      [
        for (final MapEntry(:key, :value) in fields.entries)
          await _value(type, key, value),
      ]..sort((a, b) {
        final byField = a.field.index.compareTo(b.field.index);
        return byField != 0 ? byField : a.key.compareTo(b.key);
      });

  Future<ConflictValue> _value(String type, String key, Object? raw) async {
    final field = _fieldOf(type, key);
    final Object? value = switch (field) {
      ConflictField.project || ConflictField.parentProject =>
        raw is String ? await _ref(EntityTypes.project, raw) : raw,
      ConflictField.section =>
        raw is String ? await _ref(EntityTypes.section, raw) : raw,
      ConflictField.parentTask =>
        raw is String ? await _ref(EntityTypes.task, raw) : raw,
      ConflictField.due => _due(raw),
      ConflictField.deadline =>
        raw is Map<String, Object?> && raw[DeadlineKeys.date] is String
            ? raw[DeadlineKeys.date]
            : raw,
      ConflictField.duration => _duration(raw),
      _ => raw,
    };
    return ConflictValue(field: field, key: key, value: value);
  }

  /// Значение неожиданного вида остаётся как есть — экран покажет его JSON.
  static Object? _due(Object? raw) {
    if (raw is! Map<String, Object?>) return raw;
    final (date, time, tz) = (
      raw[DueKeys.date],
      raw[DueKeys.time],
      raw[DueKeys.tz],
    );
    if (date is! String) return raw;
    return Due(
      date: date,
      time: time is String ? time : null,
      tz: tz is String ? tz : null,
    );
  }

  static Object? _duration(Object? raw) {
    if (raw is! Map<String, Object?>) return raw;
    final (amount, unit) = (raw[DurationKeys.amount], raw[DurationKeys.unit]);
    if (amount is! int || unit is! String) return raw;
    return TaskDuration(amount: amount, unit: unit);
  }

  static ConflictEntity _entityOf(String type) => switch (type) {
    EntityTypes.task => ConflictEntity.task,
    EntityTypes.project => ConflictEntity.project,
    EntityTypes.section => ConflictEntity.section,
    EntityTypes.label => ConflictEntity.label,
    EntityTypes.taskLabel => ConflictEntity.taskLabel,
    _ => ConflictEntity.other,
  };

  static ConflictField _fieldOf(String type, String key) => switch ((
    type,
    key,
  )) {
    (_, Op.deletedField) => ConflictField.deleted,
    (EntityTypes.task, TaskFields.content) => ConflictField.content,
    (EntityTypes.task, TaskFields.description) => ConflictField.description,
    (EntityTypes.task, TaskFields.projectId) ||
    (EntityTypes.section, SectionFields.projectId) => ConflictField.project,
    (EntityTypes.task, TaskFields.sectionId) => ConflictField.section,
    (EntityTypes.task, TaskFields.parentId) => ConflictField.parentTask,
    (EntityTypes.project, ProjectFields.parentId) =>
      ConflictField.parentProject,
    (EntityTypes.task, TaskFields.priority) => ConflictField.priority,
    (EntityTypes.task, TaskFields.due) => ConflictField.due,
    (EntityTypes.task, TaskFields.deadline) => ConflictField.deadline,
    (EntityTypes.task, TaskFields.duration) => ConflictField.duration,
    (EntityTypes.task, TaskFields.isCompleted) => ConflictField.completed,
    (
      EntityTypes.project || EntityTypes.section || EntityTypes.label,
      ProjectFields.name,
    ) =>
      ConflictField.name,
    (EntityTypes.project || EntityTypes.label, ProjectFields.color) =>
      ConflictField.color,
    (EntityTypes.project || EntityTypes.label, ProjectFields.isFavorite) =>
      ConflictField.favorite,
    (EntityTypes.project || EntityTypes.section, ProjectFields.isArchived) =>
      ConflictField.archived,
    (EntityTypes.project, ProjectFields.viewStyle) => ConflictField.viewStyle,
    _ => ConflictField.other,
  };
}

/// Более ранняя и более поздняя стороны и действующие значения полей
/// карточки (у удаления — пусто: решает только `deleted`).
typedef _Sides = (ConflictSide, ConflictSide, List<ConflictValue>);

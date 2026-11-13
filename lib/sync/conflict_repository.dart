import 'package:oplog_sync/oplog_sync.dart';

import '../data/app_database.dart';
import '../data/local_meta_dao.dart';
import '../data/projection/due_rule.dart';
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
/// Конфликты по полям из [silentFields] и сущностям типов из
/// [silentEntityTypes] не показываются: по текущим правилам это не конфликт
/// (записаны до того, как поле или тип стали «молчащими»), и «Пересобрать
/// базу из журнала» их удалит. Конфликты общей темы не
/// показываются, пока на устройстве выключена «Синхронизировать тему»: тема
/// на нём своя, спор его не касается (решение 3А конца этапа M2).
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

  /// Место задачи — что пишет перенос: выбор стороны пишет его целиком
  /// (решение 4А plans/m4 «Ход M4.3»), порядок — вместе с местом, иначе
  /// задача встала бы по порядку из чужого проекта.
  static const Set<String> _taskPlacement = {
    TaskFields.projectId,
    TaskFields.sectionId,
    TaskFields.parentId,
    TaskFields.orderKey,
  };

  /// Место раздела и проекта — проект или родитель с порядком, как пишет их
  /// перенос.
  static const Set<String> _sectionPlacement = {
    SectionFields.projectId,
    SectionFields.orderKey,
  };
  static const Set<String> _projectPlacement = {
    ProjectFields.parentId,
    ProjectFields.orderKey,
  };

  /// Поля общей темы в `settings`.
  static const Set<String> _themeFields = {
    SettingsFields.themeId,
    SettingsFields.themeAppearance,
  };

  /// Карточки сейчас и после каждого изменения конфликтов, полей или
  /// переключателя «Синхронизировать тему» (`local_meta`).
  Stream<List<ConflictCard>> watch() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.conflicts, _db.fieldVersions, _db.localMeta},
      )
      .watch()
      .asyncMap((_) => load());

  /// Открытые конфликты карточками, новые сверху.
  Future<List<ConflictCard>> load() =>
      _db.transaction(() async => _cards((await _open()).shown));

  /// Карточки, о которых это устройство ещё не уведомляло, — и запомнить,
  /// что уведомило обо всех открытых. Решение по таблице конфликтов, а не по
  /// отчёту прохода: конфликт из перечитанного после сбоя чанка, из прохода,
  /// упавшего после применения, и из переиздания (`adopt`) в отчёт не
  /// попадает (О-9). Запоминаются только открытые: разрешённые выпадают сами.
  /// Скрытый сейчас конфликт темы, о котором уже уведомили, остаётся в
  /// памяти: после включения «Синхронизировать тему» он не новый.
  Future<List<ConflictCard>> takeUnnotified() => _db.transaction(() async {
    final (:shown, :hidden) = await _open();
    final cards = await _cards(shown);
    final notified = await _meta.notifiedConflicts();
    final open = {
      for (final card in cards) ...card.conflictIds,
      ...notified.where(hidden.contains),
    };
    if (open.length != notified.length || !notified.containsAll(open)) {
      await _meta.setNotifiedConflicts(open);
    }
    return [
      for (final card in cards)
        if (card.conflictIds.any((id) => !notified.contains(id))) card,
    ];
  });

  /// Открытые конфликты: показываемые и скрытые на этом устройстве (тема при
  /// выключенной «Синхронизировать тему»).
  Future<({List<Conflict> shown, Set<String> hidden})> _open() async {
    final themeShared = await _meta.themeSync();
    final shown = <Conflict>[];
    final hidden = <String>{};
    for (final c in await _store.conflicts()) {
      if (c.resolved ||
          silentFields.contains(c.field) ||
          silentEntityTypes.contains(c.entityType)) {
        continue;
      }
      if (!themeShared &&
          c.entityType == EntityTypes.settings &&
          _themeFields.contains(c.field)) {
        hidden.add(c.id);
      } else {
        shown.add(c);
      }
    }
    return (shown: shown, hidden: hidden);
  }

  Future<List<ConflictCard>> _cards(List<Conflict> open) async {
    if (open.isEmpty) return const [];
    final opsByEntity = <String, Map<String, Op>>{};
    final groups = <String, List<(Conflict, Op, Op)>>{};
    final periods = <String, _Period>{};
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
      // — одна карточка. Правка: споры правки сущности между одной парой
      // устройств за один период — одна карточка (решение 11 plans/m4,
      // решения 1А и 2А «Ход M4.3»): после долгого офлайна N правок поля
      // против одной дали бы N одинаковых карточек. Период — что каждое
      // устройство знало о сущности (`base`): ни одно действие из споров с
      // тем же ключом не видело действий другого устройства из них же
      // (каждое спорит с действием того же `base`, значит, новее его).
      // Синхронизация меняет `base`, и спор, не решённый до неё, остаётся
      // своей карточкой — иначе последние действия обоих показывали бы в его
      // поле победителя. У настроек — карточка на раздел окна: тема и
      // «Основное» выбираются отдельно.
      if (_isDelete(c)) {
        (groups['delete $entityKey'] ??= []).add((c, older, newer));
        continue;
      }
      final (first, second) = older.nodeId.compareTo(newer.nodeId) < 0
          ? (older, newer)
          : (newer, older);
      final pair =
          'edit $entityKey ${_settingsSection(c)} '
          '${first.nodeId} ${second.nodeId}';
      final key = '$pair ${first.base} ${second.base}';
      periods[key] = (pair: pair, bases: (first.base, second.base));
      (groups[key] ??= []).add((c, older, newer));
    }
    final carried = _carryToLatest(groups, periods);
    final thisNode = await _meta.nodeId();
    final former = await _meta.previousNodeIds();
    final cards = [
      for (final MapEntry(:key, value: group) in groups.entries)
        _withDevices(
          await _card(
            group,
            opsByEntity[_entityKey(group.first.$1)]!,
            carried: carried[key] ?? const [],
          ),
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

  /// Спор поля, которое та же пара устройств снова спорила в более позднем
  /// периоде, уходит в карточку позднего (решение 5А plans/m4 «Ход M4.3»):
  /// обе стороны изменили поле, уже увидев победителя, и старый спор о нём
  /// устарел, а выбор поля закрывает все его конфликты (`resolveConflict`
  /// пакета) — и новый, которого пользователь не видел. Поле уходит с
  /// группой ([_unitFields]: место задачи — целиком, «выполнена» — с датой
  /// выполнения). Опустевшая карточка убирается. Возвращает ключ карточки →
  /// перенесённые в неё споры.
  ///
  /// Порядок периодов пары — по знанию устройств: большее из двух `base`
  /// сторон, затем меньшее (`null` — меньше любого). Знание каждого
  /// устройства только растёт, поэтому период, где оба знали не меньше, а
  /// одно — больше, идёт позже. Остальное — одинаковые наборы `base` у
  /// разных устройств — по самому позднему HLC споров, затем по ключу:
  /// порядок одинаков на всех устройствах.
  static Map<String, List<(Conflict, Op, Op)>> _carryToLatest(
    Map<String, List<(Conflict, Op, Op)>> groups,
    Map<String, _Period> periods,
  ) {
    final latest = {
      for (final key in periods.keys)
        key: groups[key]!.map((g) => g.$3.hlc).reduce((a, b) => a < b ? b : a),
    };
    int byHlc(Hlc? a, Hlc? b) => a == null
        ? (b == null ? 0 : -1)
        : b == null
        ? 1
        : a.compareTo(b);
    (Hlc?, Hlc?) descending(String key) {
      final (x, y) = periods[key]!.bases;
      return byHlc(x, y) >= 0 ? (x, y) : (y, x);
    }

    int order(String a, String b) {
      final ((aHi, aLo), (bHi, bLo)) = (descending(a), descending(b));
      for (final c in [
        () => byHlc(aHi, bHi),
        () => byHlc(aLo, bLo),
        () => latest[a]!.compareTo(latest[b]!),
        () => a.compareTo(b),
      ]) {
        final result = c();
        if (result != 0) return result;
      }
      return 0;
    }

    // От самого позднего периода к раннему: поле достаётся первому, кто его
    // спорил.
    final target = <String, String>{}; // пара и поле → ключ карточки
    final carried = <String, List<(Conflict, Op, Op)>>{};
    for (final key in periods.keys.toList()..sort((a, b) => order(b, a))) {
      final pair = periods[key]!.pair;
      groups[key]!.removeWhere((g) {
        final to = target['$pair ${_unitFields(g.$1).first}'] ??= key;
        if (to == key) return false;
        (carried[to] ??= []).add(g);
        return true;
      });
      if (groups[key]!.isEmpty) groups.remove(key);
    }
    return carried;
  }

  /// Поля, которые выбираются вместе с полем спора [c]: место задачи,
  /// раздела и проекта — целиком, с порядком (решение 4А), «выполнена» — с
  /// датой выполнения и именами меток на момент завершения (решение 1А к
  /// коммиту 3 M2.3). Первое — само поле или представитель группы.
  static Set<String> _unitFields(Conflict c) {
    final place = switch (c.entityType) {
      EntityTypes.task => _taskPlacement,
      EntityTypes.section => _sectionPlacement,
      EntityTypes.project => _projectPlacement,
      _ => const <String>{},
    };
    if (place.contains(c.field)) {
      return place;
    }
    if (c.entityType == EntityTypes.task && c.field == TaskFields.isCompleted) {
      return const {
        TaskFields.isCompleted,
        TaskFields.completedAt,
        TaskFields.completedLabelNames,
      };
    }
    return {c.field};
  }

  /// Раздел окна настроек поля спора; у других сущностей — пусто.
  static String _settingsSection(Conflict c) =>
      c.entityType != EntityTypes.settings
      ? ''
      : _themeFields.contains(c.field)
      ? 'theme'
      : 'general';

  static bool _isDelete(Conflict c) =>
      c.kind == ConflictKind.delete || c.field == Op.deletedField;

  /// [carried] — споры, перенесённые из более ранних периодов
  /// ([_carryToLatest]): карточка закрывает и их.
  Future<ConflictCard> _card(
    List<(Conflict, Op, Op)> group,
    Map<String, Op> entityOps, {
    required List<(Conflict, Op, Op)> carried,
  }) async {
    final first = group.first.$1;
    final (type, id) = (first.entityType, first.entityId);
    final (older, newer, current) = _isDelete(first)
        ? await _deleteSides(type, id, group)
        : await _editSides(type, id, group, carried, entityOps.values);
    final (:title, :ownerTitle, :ownerId) = await _titles(type, id);
    return ConflictCard(
      entity: _entityOf(type),
      entityId: id,
      title: title,
      ownerTitle: ownerTitle,
      ownerId: ownerId,
      isInbox: await _isInbox(type, id),
      isDelete: _isDelete(first),
      conflictIds: [
        for (final (c, _, _) in [...group, ...carried]) c.id,
      ]..sort(),
      older: older,
      newer: newer,
      current: older.isCurrent || newer.isCurrent ? const [] : current,
    );
  }

  /// Стороны правки (решение 11 plans/m4, решения 6А и 1А «Ход M4.3»): у
  /// каждого устройства значение поля — его последняя правка этой группы
  /// полей ([_unitFields]), сделанная, пока оно знало о сущности не больше,
  /// чем в карточке (`base`), время стороны — последняя из них. Пишутся только поля споров карточки с их группой: поле, о котором
  /// спора не было, действует, как записало устройство. Поле группы, которое
  /// автор правки не писал, — значение, которое он видел (`seenValue`): так
  /// перенос без смены раздела возвращает и раздел. Группа, в которой
  /// стороны совпадают, не пишется (решение 3А): выбирать в ней нечего, а
  /// запись откатила бы правку, сделанную после спора; иначе — целиком (4А).
  ///
  /// Правка, сделанная при большем знании, могла видеть правку другой
  /// стороны, и её значение было бы уже выбором, а не стороной. Показываются
  /// поля, кроме «молчащих», где стороны расходятся или действует уже другое
  /// значение (выбор его сбросит), — с действующими значениями.
  Future<_Sides> _editSides(
    String type,
    String id,
    List<(Conflict, Op, Op)> group,
    List<(Conflict, Op, Op)> carried,
    Iterable<Op> entityOps,
  ) async {
    final ops = entityOps.toList();
    final bases = <String, Hlc?>{
      for (final (_, older, newer) in group) ...{
        older.nodeId: older.base,
        newer.nodeId: newer.base,
      },
    };
    if (bases.length != 2) {
      throw StateError('Спор правки $type/$id не двух устройств');
    }
    bool knewNoMore(Op op) {
      final (mine, limit) = (op.base, bases[op.nodeId]);
      return mine == null || (limit != null && !(limit < mine));
    }

    final units = {
      for (final (c, _, _) in [...group, ...carried])
        _unitFields(c).first: _unitFields(c),
    };
    // Группа полей (по первому полю) → последняя правка её полей у каждого
    // устройства, сделанная, пока оно знало о сущности не больше, чем в этой
    // карточке.
    final latest = <String, Map<String, Op>>{};
    for (final op in ops) {
      if (!bases.containsKey(op.nodeId) || !knewNoMore(op)) continue;
      for (final MapEntry(key: unit, value: fields) in units.entries) {
        if (!fields.contains(op.field)) continue;
        final byNode = latest[unit] ??= {};
        final seen = byNode[op.nodeId];
        if (seen == null || seen.hlc < op.hlc) byNode[op.nodeId] = op;
      }
    }
    Object? valueAt(Op author, String field) {
      for (final op in ops) {
        if (op.hlc == author.hlc && op.field == field) return op.value;
      }
      return seenValue(author, field, ops);
    }

    Op lastOf(String node) =>
        [for (final byNode in latest.values) byNode[node]!]
            .reduce((a, b) => a.hlc < b.hlc ? b : a);
    Map<String, Object?> valuesOf(String node) => {
      for (final MapEntry(key: unit, value: fields) in units.entries)
        for (final field in fields) field: valueAt(latest[unit]![node]!, field),
    };
    final [olderOp, newerOp] = [for (final node in bases.keys) lastOf(node)]
      ..sort((a, b) => a.hlc.compareTo(b.hlc));
    final (olderWhole, newerWhole) = (
      valuesOf(olderOp.nodeId),
      valuesOf(newerOp.nodeId),
    );
    // Расходится группа только по видимым полям: «молчащие» (порядок, дата
    // выполнения) пишутся вместе с видимым расхождением, иначе выбор менял
    // бы их без следа на карточке.
    final differ = {
      for (final fields in units.values)
        if (fields.any(
          (f) =>
              !silentFields.contains(f) &&
              !jsonEquals(olderWhole[f], newerWhole[f]),
        ))
          ...fields,
    };
    final (olderFields, newerFields) = (
      {for (final key in differ) key: olderWhole[key]},
      {for (final key in differ) key: newerWhole[key]},
    );
    final current = {
      for (final key in differ)
        if (!silentFields.contains(key))
          key: await _store.fieldValue(type, id, key),
    };
    final shown = [
      for (final key in current.keys)
        if (!jsonEquals(olderFields[key], newerFields[key]) ||
            !jsonEquals(olderFields[key], current[key]))
          key,
    ];
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
      await _values(type, {for (final key in shown) key: current[key]}),
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

  /// Заголовок карточки; у метки задачи — ещё задача-владелец: её название и
  /// id (пометка спора в строке задачи).
  Future<({String? title, String? ownerTitle, String? ownerId})> _titles(
    String type,
    String id,
  ) async {
    // У настроек имени нет: заголовок карточки — просто «Настройки».
    if (type == EntityTypes.settings) {
      return (title: null, ownerTitle: null, ownerId: null);
    }
    if (type != EntityTypes.taskLabel) {
      return (title: await _title(type, id), ownerTitle: null, ownerId: null);
    }
    final labelId = await _store.fieldValue(type, id, TaskLabelFields.labelId);
    final taskId = await _store.fieldValue(type, id, TaskLabelFields.taskId);
    return (
      title: labelId is String
          ? await _title(EntityTypes.label, labelId)
          : null,
      ownerTitle: taskId is String
          ? await _title(EntityTypes.task, taskId)
          : null,
      ownerId: taskId is String ? taskId : null,
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
    final (string, lang) = (raw[DueKeys.string], raw[DueKeys.lang]);
    return Due(
      date: date,
      time: time is String ? time : null,
      tz: tz is String ? tz : null,
      string: string is String ? string : null,
      lang: lang is String ? lang : null,
      rule: recurrenceRuleOf(raw[DueKeys.rule]),
      seriesTime: switch (raw[DueKeys.seriesTime]) {
        final String t => t,
        _ => null,
      },
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
    EntityTypes.settings => ConflictEntity.settings,
    _ => ConflictEntity.other,
  };

  static ConflictField _fieldOf(String type, String key) => switch ((
    type,
    key,
  )) {
    (_, Op.deletedField) => ConflictField.deleted,
    (EntityTypes.task, TaskFields.content) => ConflictField.content,
    (EntityTypes.task || EntityTypes.project, TaskFields.description) =>
      ConflictField.description,
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
    (EntityTypes.settings, SettingsFields.themeId) => ConflictField.theme,
    (EntityTypes.settings, SettingsFields.themeAppearance) =>
      ConflictField.appearance,
    (EntityTypes.settings, SettingsFields.smartDateRecognition) =>
      ConflictField.smartDateRecognition,
    (EntityTypes.settings, SettingsFields.resetRecurringSubtasks) =>
      ConflictField.resetRecurringSubtasks,
    _ => ConflictField.other,
  };
}

/// Период карточки правки: сущность, раздел настроек и пара устройств, и
/// `base` каждого из них (в порядке id узлов).
typedef _Period = ({String pair, (Hlc?, Hlc?) bases});

/// Более ранняя и более поздняя стороны и действующие значения полей
/// карточки (у удаления — пусто: решает только `deleted`).
typedef _Sides = (ConflictSide, ConflictSide, List<ConflictValue>);

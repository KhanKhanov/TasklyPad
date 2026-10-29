import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/sync_status.dart';
import 'package:planner/features/conflicts/ui/conflict_values.dart';
import 'package:planner/l10n/app_localizations.dart';

// Тексты карточек «Конфликты» по-русски: каждое поле каждого вида значения.
void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));

  setUpAll(() => initializeDateFormatting('ru'));

  String text(
    ConflictField field,
    Object? value, {
    ConflictEntity entity = ConflictEntity.task,
    String key = 'k',
  }) => conflictValueText(
    l10n,
    'ru',
    entity,
    ConflictValue(field: field, key: key, value: value),
  );

  test('значения полей — как в интерфейсе задачи и проекта', () {
    const work = ConflictRef(id: 'p', title: 'Работа');
    final cases = <(String, String)>[
      (text(ConflictField.content, 'Отчёт'), 'Отчёт'),
      (text(ConflictField.content, ''), '(пусто)'),
      (text(ConflictField.description, 'текст'), 'текст'),
      (text(ConflictField.project, null), 'Входящие'),
      (text(ConflictField.project, work), 'Работа'),
      (
        text(ConflictField.project, const ConflictRef(id: 'i', isInbox: true)),
        'Входящие',
      ),
      (
        text(ConflictField.project, work.copyWith(isDeleted: true)),
        'Работа (удалено)',
      ),
      (
        text(ConflictField.section, const ConflictRef(id: 'x')),
        'не найдено на этом устройстве',
      ),
      (text(ConflictField.section, null), 'Без раздела'),
      (text(ConflictField.parentTask, null), 'Без родителя'),
      (text(ConflictField.priority, 1), 'Приоритет 1'),
      (text(ConflictField.due, null), 'Без срока'),
      (
        text(
          ConflictField.due,
          const Due(date: '2026-10-28', time: '09:30', tz: 'Europe/Moscow'),
        ),
        '28 окт. 2026 г. 09:30 (Europe/Moscow)',
      ),
      (text(ConflictField.deadline, '2026-11-01'), '1 нояб. 2026 г.'),
      (text(ConflictField.deadline, null), 'Без дедлайна'),
      (
        text(
          ConflictField.duration,
          const TaskDuration(amount: 1, unit: 'day'),
        ),
        '1440 мин',
      ),
      (text(ConflictField.duration, null), 'Без длительности'),
      (text(ConflictField.completed, true), 'Выполнена'),
      (text(ConflictField.completed, false), 'Не выполнена'),
      (text(ConflictField.color, 'berry_red'), 'Ягодный'),
      (text(ConflictField.favorite, true), 'В избранном'),
      (text(ConflictField.archived, false), 'Не в архиве'),
      (text(ConflictField.viewStyle, 'board'), 'Доска'),
      (text(ConflictField.deleted, true), 'Удалено'),
      (text(ConflictField.deleted, false), 'Восстановлено'),
      (
        text(ConflictField.deleted, true, entity: ConflictEntity.taskLabel),
        'Метка снята',
      ),
      (text(ConflictField.theme, 'taskly'), 'Taskly'),
      (text(ConflictField.theme, 'kale'), 'kale'),
      (text(ConflictField.appearance, 'light'), 'Светлый'),
      (text(ConflictField.appearance, 'dark'), 'Тёмный'),
      (text(ConflictField.appearance, 'system'), 'Системный'),
      (text(ConflictField.appearance, 'sepia'), '"sepia"'),
      (text(ConflictField.other, {'a': 1}), '{"a":1}'),
      (text(ConflictField.priority, 'странно'), '"странно"'),
    ];
    for (final (actual, expected) in cases) {
      // intl ставит в датах неразрывные пробелы (U+00A0, U+202F).
      expect(actual.replaceAll(RegExp('[\u00a0\u202f]'), ' '), expected);
    }
  });

  test('заголовок и уведомление: «Входящие» переводом, метка задачи — с '
      'задачей, несколько карточек — числом', () {
    ConflictCard card(
      ConflictEntity entity, {
      String? title,
      String? owner,
      bool inbox = false,
      bool delete = false,
    }) {
      final side = ConflictSide(
        nodeId: 'n',
        at: DateTime.utc(2026),
        deletes: false,
        values: const [
          ConflictValue(field: ConflictField.name, key: 'name'),
          ConflictValue(field: ConflictField.color, key: 'color'),
        ],
        fields: const {},
        isCurrent: false,
      );
      return ConflictCard(
        entity: entity,
        entityId: 'e',
        title: title,
        ownerTitle: owner,
        isInbox: inbox,
        isDelete: delete,
        conflictIds: const ['c'],
        older: side,
        newer: side,
      );
    }

    expect(
      conflictEntityTitle(l10n, card(ConflictEntity.project, inbox: true)),
      'Проект «Входящие»',
    );
    expect(
      conflictEntityTitle(
        l10n,
        card(ConflictEntity.taskLabel, title: 'дом', owner: 'Отчёт'),
      ),
      'Метка «дом» у задачи «Отчёт»',
    );
    expect(
      conflictEntityTitle(l10n, card(ConflictEntity.task)),
      'Задача «без названия»',
    );
    expect(
      conflictEntityTitle(l10n, card(ConflictEntity.settings)),
      'Настройки',
    );
    expect(
      conflictFieldTitle(
        l10n,
        const ConflictValue(field: ConflictField.theme, key: 'theme_id'),
      ),
      'Тема',
    );
    expect(
      conflictFieldTitle(
        l10n,
        const ConflictValue(
          field: ConflictField.appearance,
          key: 'theme_appearance',
        ),
      ),
      'Внешний вид',
    );
    expect(
      conflictNoticeText(l10n, [card(ConflictEntity.label, title: 'дом')]),
      'Конфликт: Метка «дом», поля Название, Цвет',
    );
    expect(
      conflictNoticeText(l10n, [
        card(ConflictEntity.task, title: 'a', delete: true),
      ]),
      'Конфликт удаления: Задача «a»',
    );
    expect(
      conflictNoticeText(l10n, [
        card(ConflictEntity.task),
        card(ConflictEntity.task),
        card(ConflictEntity.task),
      ]),
      '3 новых конфликта синхронизации',
    );
    for (final (n, text) in [
      (1, '1 новый конфликт синхронизации'),
      (5, '5 новых конфликтов синхронизации'),
      (11, '11 новых конфликтов синхронизации'),
      (21, '21 новый конфликт синхронизации'),
    ]) {
      expect(l10n.conflictToastMany(n), text);
    }
  });

  test('устройство стороны: имя из папки; без папки — «Это устройство», '
      'прежний id, конец id', () {
    ConflictSide side(String node, {bool self = false, bool former = false}) =>
        ConflictSide(
          nodeId: node,
          isThisDevice: self,
          isFormerThisDevice: former,
          at: DateTime.utc(2026),
          deletes: false,
          values: const [],
          fields: const {},
          isCurrent: false,
        );
    const pc = SyncDevice(
      nodeId: 'node-pc',
      isThisDevice: true,
      name: 'DESKTOP',
    );
    expect(
      conflictDevice(l10n, side('node-pc', self: true), [pc]),
      'DESKTOP — это устройство',
    );
    expect(
      conflictDevice(l10n, side('node-pc', self: true), []),
      'Это устройство',
    );
    expect(
      conflictDevice(l10n, side('old', former: true), []),
      l10n.deviceFormerThis,
    );
    expect(
      conflictDevice(l10n, side('0123456789abcdef'), []),
      'Устройство …abcdef',
    );
  });
}

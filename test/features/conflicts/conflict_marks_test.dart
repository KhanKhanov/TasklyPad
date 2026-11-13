import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/features/conflicts/state/conflict_marks.dart';

ConflictSide _side(List<ConflictField> fields) => ConflictSide(
  nodeId: 'n',
  at: DateTime.utc(2026, 11, 1),
  deletes: false,
  values: [for (final f in fields) ConflictValue(field: f, key: f.name)],
  fields: const {},
  isCurrent: false,
);

ConflictCard _card(
  ConflictEntity entity,
  String id,
  List<ConflictField> fields, {
  bool isInbox = false,
  bool isDelete = false,
  String? ownerId,
}) => ConflictCard(
  entity: entity,
  entityId: id,
  isInbox: isInbox,
  ownerId: ownerId,
  isDelete: isDelete,
  conflictIds: ['c-$entity-$id-${fields.length}'],
  older: _side(fields),
  newer: _side(fields),
);

void main() {
  group('кто помечается', () {
    final cases =
        <
          ({
            String name,
            ConflictCard card,
            ConflictEntity on,
            String id,
            bool marked,
          })
        >[
          (
            name: 'задача — любое поле',
            card: _card(ConflictEntity.task, 't', [ConflictField.priority]),
            on: ConflictEntity.task,
            id: 't',
            marked: true,
          ),
          (
            name: 'задача — удаление',
            card: _card(ConflictEntity.task, 't', [], isDelete: true),
            on: ConflictEntity.task,
            id: 't',
            marked: true,
          ),
          (
            name: 'метка задачи помечает задачу-владельца',
            card: _card(ConflictEntity.taskLabel, 'x', [
              ConflictField.deleted,
            ], ownerId: 't'),
            on: ConflictEntity.task,
            id: 't',
            marked: true,
          ),
          (
            name: 'метка задачи без владельца — никого',
            card: _card(ConflictEntity.taskLabel, 'x', [ConflictField.deleted]),
            on: ConflictEntity.task,
            id: 'x',
            marked: false,
          ),
          (
            name: 'проект — имя',
            card: _card(ConflictEntity.project, 'p', [ConflictField.name]),
            on: ConflictEntity.project,
            id: 'p',
            marked: true,
          ),
          (
            name: 'проект — цвет',
            card: _card(ConflictEntity.project, 'p', [
              ConflictField.favorite,
              ConflictField.color,
            ]),
            on: ConflictEntity.project,
            id: 'p',
            marked: true,
          ),
          (
            name: 'проект — только описание',
            card: _card(ConflictEntity.project, 'p', [
              ConflictField.description,
            ]),
            on: ConflictEntity.project,
            id: 'p',
            marked: false,
          ),
          (
            name: 'проект — архив и удаление без имени и цвета',
            card: _card(ConflictEntity.project, 'p', [
              ConflictField.archived,
            ], isDelete: true),
            on: ConflictEntity.project,
            id: 'p',
            marked: false,
          ),
          (
            name:
                'проект — удаление против переименования (1А: удаление '
                'не помечает)',
            card: _card(ConflictEntity.project, 'p', [
              ConflictField.name,
            ], isDelete: true),
            on: ConflictEntity.project,
            id: 'p',
            marked: false,
          ),
          (
            name: 'метка — удаление против смены цвета',
            card: _card(ConflictEntity.label, 'l', [
              ConflictField.color,
            ], isDelete: true),
            on: ConflictEntity.label,
            id: 'l',
            marked: false,
          ),
          (
            name: 'Входящие не помечаются',
            card: _card(ConflictEntity.project, 'in', [
              ConflictField.name,
            ], isInbox: true),
            on: ConflictEntity.project,
            id: 'in',
            marked: false,
          ),
          (
            name: 'раздел — имя',
            card: _card(ConflictEntity.section, 's', [ConflictField.name]),
            on: ConflictEntity.section,
            id: 's',
            marked: true,
          ),
          (
            name: 'метка — цвет',
            card: _card(ConflictEntity.label, 'l', [ConflictField.color]),
            on: ConflictEntity.label,
            id: 'l',
            marked: true,
          ),
          (
            name: 'метка — избранное',
            card: _card(ConflictEntity.label, 'l', [ConflictField.favorite]),
            on: ConflictEntity.label,
            id: 'l',
            marked: false,
          ),
          (
            name: 'фильтр — запрос (4А plans/m5)',
            card: _card(ConflictEntity.filter, 'f', [ConflictField.query]),
            on: ConflictEntity.filter,
            id: 'f',
            marked: true,
          ),
          (
            name: 'фильтр — имя',
            card: _card(ConflictEntity.filter, 'f', [ConflictField.name]),
            on: ConflictEntity.filter,
            id: 'f',
            marked: true,
          ),
          (
            name: 'фильтр — описание и избранное без пометки',
            card: _card(ConflictEntity.filter, 'f', [
              ConflictField.description,
              ConflictField.favorite,
            ]),
            on: ConflictEntity.filter,
            id: 'f',
            marked: false,
          ),
          (
            name: 'фильтр — удаление против правки запроса',
            card: _card(ConflictEntity.filter, 'f', [
              ConflictField.query,
            ], isDelete: true),
            on: ConflictEntity.filter,
            id: 'f',
            marked: false,
          ),
          (
            name: 'настройки — нигде',
            card: _card(ConflictEntity.settings, 'st', [ConflictField.name]),
            on: ConflictEntity.settings,
            id: 'st',
            marked: false,
          ),
          (
            name: 'прочее — нигде',
            card: _card(ConflictEntity.other, 'o', [ConflictField.name]),
            on: ConflictEntity.other,
            id: 'o',
            marked: false,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        final marks = ConflictMarks.of([c.card]);
        expect(marks.has(c.on, c.id), c.marked);
        expect(marks.cardsFor(c.on, c.id).isNotEmpty, c.marked);
      });
    }
  });

  test('cardsFor задачи — её карточки и карточки её меток', () {
    final own = _card(ConflictEntity.task, 't', [ConflictField.due]);
    final label = _card(ConflictEntity.taskLabel, 'x', [
      ConflictField.deleted,
    ], ownerId: 't');
    final foreign = _card(ConflictEntity.task, 'u', [ConflictField.due]);
    final marks = ConflictMarks.of([own, label, foreign]);
    expect(marks.cardsFor(ConflictEntity.task, 't'), [own, label]);
    expect(marks.cardsFor(ConflictEntity.task, 'u'), [foreign]);
  });

  test('cardsFor помеченного проекта — все его карточки, и описания тоже; '
      'непомеченного — пусто (план 1Б)', () {
    final name = _card(ConflictEntity.project, 'p', [ConflictField.name]);
    final description = _card(ConflictEntity.project, 'p', [
      ConflictField.description,
    ]);
    final onlyDescription = _card(ConflictEntity.project, 'q', [
      ConflictField.description,
    ]);
    final marks = ConflictMarks.of([name, description, onlyDescription]);
    expect(marks.cardsFor(ConflictEntity.project, 'p'), [name, description]);
    expect(marks.has(ConflictEntity.project, 'q'), isFalse);
    expect(marks.cardsFor(ConflictEntity.project, 'q'), isEmpty);
  });

  test('без карточек — никто не помечен', () {
    expect(ConflictMarks.of(const []).has(ConflictEntity.task, 't'), isFalse);
  });
}

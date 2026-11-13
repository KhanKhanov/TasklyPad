import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/domain/view_options.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Команды фильтров (план M5 «Модель данных фильтра»); лимиты О-80 —
// test/features/limits_test.dart.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  Future<List<String>> order() async => [
    for (final f in (await app.read()).filters) f.name,
  ];

  /// [action] отклонено с [reason], и ни одной новой op.
  Future<void> rejectsWithoutOps(
    Future<Object?> Function() action,
    RejectReason reason,
  ) async {
    final before = (await device.ownOps()).length;
    await expectLater(action(), _rejected(reason));
    expect((await device.ownOps()).length, before);
  }

  test('добавление — имя и запрос без пробелов по краям, в конец списка, '
      'цвет по умолчанию; описания и избранного в журнале нет', () async {
    await app.filters.add(name: 'Первый', query: 'p1');
    final id = await app.filters.add(name: '  Срочное ', query: ' p1 & today ');

    expect(await order(), ['Первый', 'Срочное']);
    final saved = (await app.read()).filter(id)!;
    expect(
      (saved.name, saved.query, saved.color, saved.isFavorite),
      ('Срочное', 'p1 & today', 'charcoal', false),
    );
    expect((await device.entity(EntityTypes.filter, id))!.keys.toSet(), {
      FilterFields.name,
      FilterFields.query,
      FilterFields.color,
      FilterFields.isFavorite,
      FilterFields.orderKey,
    });
  });

  test('пустое имя или запрос — отказ без записи, и при правке', () async {
    await rejectsWithoutOps(
      () => app.filters.add(name: '  ', query: 'p1'),
      RejectReason.emptyName,
    );
    await rejectsWithoutOps(
      () => app.filters.add(name: 'Срочное', query: ' '),
      RejectReason.emptyQuery,
    );
    final id = await app.filters.add(name: 'Срочное', query: 'p1');
    await rejectsWithoutOps(
      () => app.filters.edit(id, query: ''),
      RejectReason.emptyQuery,
    );
  });

  test('одинаковые имена допустимы (допущение О-69)', () async {
    await app.filters.add(name: 'Срочное', query: 'p1');
    await app.filters.add(name: 'срочное', query: 'p2');
    expect(await order(), ['Срочное', 'срочное']);
  });

  test('правка пишет одной записью только переданные поля; описание из '
      'пробелов — пустое', () async {
    final id = await app.filters.add(name: 'Срочное', query: 'p1');
    final before = (await device.ownOps()).length;

    await app.filters.edit(
      id,
      query: 'p1 | p2',
      color: 'red',
      isFavorite: true,
    );
    final ops = (await device.ownOps()).skip(before).toList();
    expect(
      {for (final op in ops) op.field},
      {FilterFields.query, FilterFields.color, FilterFields.isFavorite},
    );
    expect({for (final op in ops) op.hlc}, hasLength(1));

    await app.filters.setDescription(id, 'на сегодня');
    expect((await app.read()).filter(id)!.description, 'на сегодня');
    await app.filters.setDescription(id, '   ');
    expect((await app.read()).filter(id)!.description, '');

    final saved = (await app.read()).filter(id)!;
    expect(
      (saved.name, saved.query, saved.color, saved.isFavorite),
      ('Срочное', 'p1 | p2', 'red', true),
    );
  });

  test('правка без полей — ни одной op', () async {
    final id = await app.filters.add(name: 'Срочное', query: 'p1');
    final before = (await device.ownOps()).length;
    await app.filters.edit(id);
    expect((await device.ownOps()).length, before);
  });

  test('фильтра нет (удалён, в том числе на другом устройстве) — notFound '
      'без записи', () async {
    final id = await app.filters.add(name: 'Срочное', query: 'p1');
    await app.filters.delete(id);
    expect((await app.read()).filter(id), isNull);
    for (final action in <Future<Object?> Function()>[
      () => app.filters.edit(id, name: 'Важное'),
      () => app.filters.setFavorite(id, true),
      () => app.filters.reorder(id),
      () => app.filters.duplicate(id, name: 'Копия'),
      () => app.filters.delete(id),
    ]) {
      await rejectsWithoutOps(action, RejectReason.notFound);
    }
  });

  test('порядок — после указанного, первым, в конец; на месте — ни одной '
      'op', () async {
    final a = await app.filters.add(name: 'a', query: 'p1');
    final b = await app.filters.add(name: 'b', query: 'p1');
    final c = await app.filters.add(name: 'c', query: 'p1');

    await app.filters.reorder(c);
    expect(await order(), ['c', 'a', 'b']);
    await app.filters.reorder(c, afterId: b);
    expect(await order(), ['a', 'b', 'c']);
    await app.filters.reorder(a, afterId: b);
    expect(await order(), ['b', 'a', 'c']);

    final before = (await device.ownOps()).length;
    await app.filters.reorder(a, afterId: b);
    expect((await device.ownOps()).length, before);
  });

  test('дубликат — сразу после исходного: запрос, описание, цвет и '
      '«Отображение»; избранное — нет', () async {
    final source = await app.filters.add(
      name: 'Срочное',
      query: 'p1 & today',
      color: 'red',
      isFavorite: true,
    );
    await app.filters.add(name: 'Последний', query: 'p4');
    await app.filters.setDescription(source, 'на сегодня');
    final view = ViewOptions(viewType: ViewType.filter, objectId: source);
    await app.views.save(view, view.copyWith(grouping: Grouping.priority));

    final copy = await app.filters.duplicate(source, name: 'Копия Срочное');

    expect(await order(), ['Срочное', 'Копия Срочное', 'Последний']);
    final saved = (await app.read()).filter(copy)!;
    expect(
      (saved.query, saved.description, saved.color, saved.isFavorite),
      ('p1 & today', 'на сегодня', 'red', false),
    );
    expect(
      (await app.viewsRepo.load(ViewType.filter, objectId: copy)).grouping,
      Grouping.priority,
    );
  });

  test('после самого себя — ни одной op', () async {
    final a = await app.filters.add(name: 'a', query: 'p1');
    await app.filters.add(name: 'b', query: 'p1');
    final before = (await device.ownOps()).length;
    await app.filters.reorder(a, afterId: a);
    expect((await device.ownOps()).length, before);
    expect(await order(), ['a', 'b']);
  });

  test('дубликат с именем из пробелов — отказ без записи', () async {
    final id = await app.filters.add(name: 'Срочное', query: 'p1');
    await rejectsWithoutOps(
      () => app.filters.duplicate(id, name: '   '),
      RejectReason.emptyName,
    );
  });

  test('дубликат между соседями с одним ключом (добавлены офлайн на двух '
      'устройствах) — сразу после исходного', () async {
    Future<String> raw(String name) =>
        device.services.mutator.create(EntityTypes.filter, {
          FilterFields.name: name,
          FilterFields.query: 'p1',
          FilterFields.orderKey: 'a0',
        });
    await raw('x');
    await raw('y');
    final names = await order();
    final first = (await app.read()).filters.first.id;

    await app.filters.duplicate(first, name: 'Копия');

    expect(await order(), [names[0], 'Копия', names[1]]);
  });
}

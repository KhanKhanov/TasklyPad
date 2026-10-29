import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:oplog_sync/testing.dart';
import 'package:planner/data/projection/entity_fields.dart';

import 'support/drift_probe.dart';

// Главный инвариант проекций: база, накопленная правками и синхронизацией,
// совпадает с пересобранной из журнала (rebuildFromOps), и узлы с одинаковым
// журналом приходят к одинаковой базе.

DriftProbe _probeOf(ScenarioNode node) => node.probe as DriftProbe;

Future<ScenarioNode> _node(String id) async => ScenarioNode(
  DriftProbe(memoryDatabase()),
  id,
  silentFields: {TaskFields.orderKey},
);

/// Состояние узла не меняется от rebuild и совпадает с reproject.
Future<Map<String, Object?>> _checkRebuildStable(ScenarioNode node) async {
  final db = _probeOf(node).db;
  final before = await dumpSyncedState(db);
  await node.engine.rebuild();
  expect(
    await dumpSyncedState(db),
    before,
    reason: 'rebuild на ${node.engine.nodeId}',
  );
  await node.probe.checkConsistency();
  return before;
}

void main() {
  test('правки, срок, удаление, воскрешение, неизвестные поле и тип, конфликт '
      'и его разрешение — rebuild не меняет базу, узлы совпадают', () async {
    final a = await _node('a');
    final b = await _node('b');

    await a.engine.mutate(EntityTypes.project, 'p1', {
      ProjectFields.name: 'Дом',
      ProjectFields.color: 'green',
    });
    await a.engine.mutate(EntityTypes.task, 't1', {
      TaskFields.content: 'Купить молоко',
      TaskFields.projectId: 'p1',
      TaskFields.priority: 4,
      TaskFields.due: {'date': '2026-10-24', 'time': '09:00'},
      'deadline': '2026-10-30', // поле из будущей версии
    });
    await a.engine.mutate(EntityTypes.task, 't2', {
      TaskFields.content: 'Лишняя',
    });
    await a.engine.mutate('section', 's1', {
      'name': 'Покупки',
    }); // тип из будущего
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(2000);
    await a.engine.mutate(EntityTypes.task, 't1', {
      TaskFields.content: 'Молоко 2 л',
    });
    await b.engine.mutate(EntityTypes.task, 't1', {
      TaskFields.content: 'Кефир',
    });
    await b.engine.mutate(EntityTypes.task, 't1', {TaskFields.priority: 1});
    await a.engine.delete(EntityTypes.task, 't2');
    await syncBoth(a, b);

    final conflict = (await a.conflicts()).single;
    a.advance(100);
    await a.engine.resolveConflict(conflict.id, {
      TaskFields.content: 'Молоко 2 л',
    });
    await a.engine.mutate(EntityTypes.task, 't2', {Op.deletedField: false});
    await a.engine.mutate(EntityTypes.task, 't1', {TaskFields.due: null});
    await syncBoth(a, b);

    final task = await _probeOf(b).db.select(_probeOf(b).db.tasks).get();
    expect(
      {for (final t in task) t.id: t.content},
      {'t1': 'Молоко 2 л', 't2': 'Лишняя'},
    );
    expect(task.firstWhere((t) => t.id == 't1').priority, 1);
    expect(task.firstWhere((t) => t.id == 't1').dueDate, isNull);
    expect((await b.conflicts()).single.resolved, isTrue);

    final onA = await _checkRebuildStable(a);
    final onB = await _checkRebuildStable(b);
    expect(onB, onA);
  });

  for (var seed = 0; seed < 50; seed++) {
    test('случайный журнал (seed $seed) — rebuild и любой порядок доставки '
        'дают одну базу', () async {
      final random = Random(seed);
      final nodes = [await _node('a'), await _node('b'), await _node('c')];
      final ids = ['t0', 't1', 't2', 't3', 'p0', 'p1', 's0', 'l0', 'x0', 'g0'];

      T pick<T>(List<T> list) => list[random.nextInt(list.length)];

      Map<String, Object?> randomFields(String id) => switch (id[0]) {
        't' => {
          for (var i = 0; i < 1 + random.nextInt(2); i++)
            ...pick<Map<String, Object?>>([
              {
                TaskFields.content: pick(['А', 'Б', 'В', 'Г']),
              },
              {TaskFields.priority: 1 + random.nextInt(4)},
              {
                TaskFields.projectId: pick(['p0', 'p1', null]),
              },
              {
                TaskFields.orderKey: pick(['a0', 'a1', 'b0']),
              },
              {
                TaskFields.due: pick<Object?>([
                  null,
                  {'date': '2026-10-2${random.nextInt(10)}'},
                  {
                    'date': '2026-11-01',
                    'time': '10:00',
                    'tz': 'Europe/Moscow',
                  },
                ]),
              },
              {Op.deletedField: random.nextBool()},
              {
                TaskFields.deadline: {
                  'date': '2026-12-0${random.nextInt(9) + 1}',
                },
              },
              {TaskFields.isCollapsed: random.nextBool()},
              {TaskFields.isCompleted: random.nextBool()},
              // Поле, которого эта версия не знает (от более новой).
              {
                'responsible_uid': pick(['u1', 'u2']),
              },
            ]),
        },
        'p' => {
          pick([ProjectFields.name, ProjectFields.color]): pick([
            'x',
            'y',
            'z',
          ]),
        },
        'l' => pick<Map<String, Object?>>([
          {
            pick([LabelFields.name, LabelFields.color]): pick(['дом', 'red']),
          },
          {Op.deletedField: random.nextBool()},
        ]),
        // Настройки — без таблицы, только `field_versions`.
        'g' => {
          pick([SettingsFields.themeId, SettingsFields.themeAppearance]): pick([
            'taskly',
            'dark',
          ]),
        },
        'x' => pick<Map<String, Object?>>([
          {TaskLabelFields.taskId: 't0', TaskLabelFields.labelId: 'l0'},
          {Op.deletedField: random.nextBool()},
        ]),
        _ => {
          SectionFields.name: pick(['Покупки', 'Работа']),
        },
      };

      for (var step = 0; step < 40; step++) {
        final node = pick(nodes);
        node.advance(random.nextInt(50));
        final roll = random.nextInt(10);
        if (roll < 7) {
          final id = pick(ids);
          final type = switch (id[0]) {
            't' => EntityTypes.task,
            'p' => EntityTypes.project,
            'l' => EntityTypes.label,
            'x' => EntityTypes.taskLabel,
            'g' => EntityTypes.settings,
            _ => EntityTypes.section,
          };
          await node.engine.mutate(type, id, randomFields(id));
        } else {
          final other = pick(nodes.where((n) => n != node).toList());
          await node.pushAllTo(other);
        }
      }
      for (var round = 0; round < 2; round++) {
        for (final from in nodes) {
          for (final to in nodes) {
            if (from != to) await from.pushAllTo(to);
          }
        }
      }

      final reference = await _checkRebuildStable(nodes.first);
      for (final node in nodes.skip(1)) {
        expect(
          await _checkRebuildStable(node),
          reference,
          reason: 'узел ${node.engine.nodeId}',
        );
      }

      // Новый узел получает весь журнал в перемешанном порядке.
      final fresh = await _node('d');
      await fresh.engine.applyAll(
        (await nodes.first.store.allOps())..shuffle(random),
      );
      expect(await _checkRebuildStable(fresh), reference, reason: 'узел d');
    });
  }
}

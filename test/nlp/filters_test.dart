import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/filter_engine.dart';
import 'package:planner/domain/filter_query.dart';
import 'package:planner/domain/markdown_text.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/nlp/filter_parser.dart';

import 'fixtures.dart';

// Табличный тест языка фильтров: строки — test/fixtures/filters.json (каждая
// форма TODOIST_SYNTAX §4), снимок — test/fixtures/filter_workspace.json.
// `expect.ast` — запись узлов каждой части (`toString`), `expect.error` — вид
// и место ошибки, `expect.tasks` — названия задач каждого списка по порядку,
// `expect.titles` — заголовки списков.

void main() {
  final rows = loadRows('filters.json');
  final snapshot = jsonDecode(
    File('test/fixtures/filter_workspace.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final now = DateTime.parse('${snapshot['now']! as String}Z');
  final ws = _workspace(snapshot);

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: '${row['input']}');
    }
  });

  for (final row in rows) {
    final input = row['input']! as String;
    final expected = expectOf(row);
    test('«$input» — ${row['source']}', () {
      if (expected['error'] case final Map<String, Object?> error) {
        expect(
          () => parseFilterQuery(input, now: now),
          throwsA(
            isA<FilterSyntaxError>()
                .having((e) => e.kind.name, 'kind', error['kind'])
                .having((e) => (e.start, e.end), 'место', (
                  error['start'],
                  error['end'],
                )),
          ),
        );
        return;
      }
      final query = parseFilterQuery(input, now: now);
      expect([for (final p in query.parts) '${p.node}'], expected['ast']);
      if (expected['titles'] case final List<Object?> titles) {
        expect([for (final p in query.parts) p.text], titles);
      }
      if (expected['tasks'] case final List<Object?> tasks) {
        final lists = evaluateFilter(
          ws,
          query,
          now: now,
          wallOf: DateTime.tryParse,
        );
        expect([
          for (final list in lists)
            [for (final t in list.tasks) plainText(t.content)],
        ], tasks);
      }
    });
  }

  test('NamePattern: подстановка в начале, середине и конце; регистр и ё', () {
    NamePattern p(List<String> parts) => NamePattern(parts);
    expect(p(['Работа']).matches('работа'), isTrue);
    expect(p(['ёлка']).matches('Елка'), isTrue);
    expect(p(['', 'Work']).matches('Homework'), isTrue);
    expect(p(['', 'Work']).matches('Workshop'), isFalse);
    expect(p(['Wel', 'me']).matches('Welcome'), isTrue);
    expect(p(['ab', 'ba']).matches('aba'), isFalse);
    expect(p(['', '']).matches(''), isTrue);
    expect(p(['', 'o', '']).matches('foo'), isTrue);
  });
}

/// Снимок из test/fixtures/filter_workspace.json: поля по умолчанию —
/// пустые, порядок `a0`, приоритет P4.
Workspace _workspace(Map<String, Object?> json) {
  List<Map<String, Object?>> list(String key) =>
      (json[key]! as List<Object?>).cast<Map<String, Object?>>();
  return Workspace(
    projects: [
      for (final p in list('projects'))
        Project(
          id: p['id']! as String,
          name: p['name']! as String,
          color: 'charcoal',
          parentId: p['parent'] as String?,
          orderKey: p['order']! as String,
          isFavorite: false,
          isArchived: p['archived'] == true,
          isInbox: p['inbox'] == true,
          viewStyle: 'list',
          isCollapsed: false,
        ),
    ],
    sections: [
      for (final s in list('sections'))
        Section(
          id: s['id']! as String,
          name: s['name']! as String,
          projectId: s['project']! as String,
          orderKey: 'a0',
          isCollapsed: false,
          isArchived: false,
        ),
    ],
    labels: [
      for (final (i, l) in list('labels').indexed)
        Label(
          id: l['id']! as String,
          name: l['name']! as String,
          color: 'charcoal',
          orderKey: 'a$i',
          isFavorite: false,
        ),
    ],
    tasks: [
      for (final t in list('tasks'))
        Task(
          id: t['id']! as String,
          content: t['content']! as String,
          description: '',
          projectId: t['project'] as String?,
          sectionId: t['section'] as String?,
          parentId: t['parent'] as String?,
          orderKey: (t['order'] as String?) ?? 'a0',
          priority: (t['priority'] as int?) ?? 4,
          due: switch (t['date']) {
            final String date => Due(
              date: date,
              time: t['time'] as String?,
              rule: switch (t['rrule']) {
                final String rrule => RecurrenceRule(
                  rrule: [rrule],
                  fromCompletion: false,
                ),
                _ => null,
              },
            ),
            _ => null,
          },
          deadline: t['deadline'] as String?,
          isCollapsed: false,
          isCompleted: t['completed'] == true,
          addedAt: t['added'] as String?,
          labelIds: [...(t['labels'] as List<Object?>? ?? const []).cast()],
        ),
    ],
  );
}

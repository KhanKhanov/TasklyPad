import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/quick_add/logic/quick_add_draft.dart';
import 'package:planner/features/quick_add/logic/suggestions.dart';
import 'package:planner/nlp/parse_context.dart';
import 'package:planner/nlp/quick_add.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Имена разбора → id по снимку (решение 1А «Ход M3.6»), чипы и токены
// (решение 4А), подсказки автодополнения.
void main() {
  late TestDevice device;
  late AppCommands app;
  late Workspace ws;
  late String work;
  late String home;
  late String calls;
  late String urgent;
  // Пятница, 23.10.2026, 9:00 — стенное время тестового устройства.
  final ctx = ParseContext(now: DateTime.utc(2026, 10, 23, 9), lang: 'en');

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
    work = await app.projects.add(name: 'Work');
    home = await app.projects.add(name: 'Home Office');
    calls = await app.sections.add(work, name: 'Calls');
    urgent = await app.labels.add(name: 'urgent');
    ws = await app.read();
  });

  tearDown(() => device.db.close());

  QuickAddResolver resolver({String? parentId}) => QuickAddResolver(
    ws: ws,
    defaults: QuickAddDefaults(projectId: inboxProjectId, parentId: parentId),
    inboxNames: {'Входящие'},
  );

  test('существующие проект, раздел и метка — id, без учёта регистра', () {
    final r = resolver().resolve('Call Bob #work /calls %URGENT', ctx);
    expect(r.draft.title, 'Call Bob');
    expect(r.draft.projectId, work);
    expect(r.draft.sectionId, calls);
    expect(r.draft.labelIds, {urgent});
    expect(r.unresolved, isEmpty);
  });

  test('проект в кавычках и «Входящие» на языке интерфейса', () {
    expect(
      resolver().resolve('Plan #"Home Office"', ctx).draft.projectId,
      home,
    );
    expect(
      resolver().resolve('Plan #Входящие', ctx).draft.projectId,
      inboxProjectId,
    );
  });

  test('неизвестные проект и метка без «Создать» — текст названия', () {
    final r = resolver().resolve('Read #Books %later', ctx);
    expect(r.draft.title, 'Read #Books %later');
    expect(r.draft.projectId, inboxProjectId);
    expect(r.draft.newProject, isNull);
    expect(r.draft.newLabels, isEmpty);
    expect(r.result.highlights, isEmpty);
  });

  test('«Создать» в автодополнении — имя уходит в новые', () {
    final r = resolver().resolve(
      'Read #Books %later',
      ctx,
      pendingProjects: {'books'},
      pendingLabels: {'Later'},
    );
    expect(r.draft.title, 'Read');
    expect(r.draft.projectId, isNull);
    expect(r.draft.newProject, 'Books');
    expect(r.draft.newLabels, ['later']);
  });

  test('раздела нет в проекте задачи — текст; раздел без проекта — в '
      'проекте по умолчанию', () {
    expect(resolver().resolve('Call /calls', ctx).draft.title, 'Call /calls');
    final inWork = QuickAddResolver(
      ws: ws,
      defaults: QuickAddDefaults(projectId: work),
    ).resolve('Call /calls', ctx);
    expect(inWork.draft.sectionId, calls);
  });

  test('раздел до проекта в строке — ищется в проекте из `#`', () {
    final r = resolver().resolve('Call /calls #Work', ctx);
    expect(r.draft.projectId, work);
    expect(r.draft.sectionId, calls);
  });

  test('подзадача: `#` и `/` — текст, место — родителя', () {
    final r = resolver(parentId: 't1').resolve('Step #Work', ctx);
    expect(r.draft.title, 'Step #Work');
    expect(r.draft.parentId, 't1');
    expect(r.draft.projectId, inboxProjectId);
  });

  test('чипы — значение, если токена нет; токен главнее чипа', () {
    const chips = ChipChoices(
      priority: 2,
      due: (due: Due(date: '2026-11-01')),
      deadline: (date: '2026-12-01'),
    );
    final plain = resolver().resolve('Pay rent', ctx, chips: chips);
    expect(plain.draft.priority, 2);
    expect(plain.draft.due?.date, '2026-11-01');
    expect(plain.draft.deadline, '2026-12-01');

    final typed = resolver().resolve('Pay rent tomorrow p1', ctx, chips: chips);
    expect(typed.draft.priority, 1);
    expect(typed.draft.due?.date, '2026-10-24');
  });

  test('«Без срока» чипом убирает срок; метки экрана остаются с токенами', () {
    final r = QuickAddResolver(
      ws: ws,
      defaults: QuickAddDefaults(projectId: inboxProjectId, labelIds: {'x'}),
    ).resolve('Pay %urgent', ctx, chips: const ChipChoices(due: (due: null)));
    expect(r.draft.due, isNull);
    expect(r.draft.labelIds, {'x', urgent});
  });

  test('умное распознавание выключено — дата остаётся в названии', () {
    final r = resolver().resolve('Pay tomorrow #Work', ctx, smartDates: false);
    expect(r.draft.title, 'Pay tomorrow');
    expect(r.draft.due, isNull);
    expect(r.draft.projectId, work);
  });

  group('подсказки', () {
    List<Suggestion> suggest(String text, {String? project}) => suggestionsFor(
      tokenQueryAt(text, text.length)!,
      resolver(),
      inboxTitle: 'Inbox',
      sectionProjectId: project ?? inboxProjectId,
    );

    test('`#` — проекты с набранным и «Создать», если имени нет', () {
      final items = suggest('Call #o');
      expect(items.map((s) => s.name), ['Inbox', 'Work', 'Home Office', 'o']);
      expect(items.last.create, isTrue);
      expect(items[2].insert, '#"Home Office"');
    });

    test('точное имя есть — «Создать» не предлагается', () {
      expect(suggest('Call #work').where((s) => s.create), isEmpty);
    });

    test('`/` — разделы проекта, без «Создать»', () {
      expect(suggest('Call /c', project: work).map((s) => s.name), ['Calls']);
      expect(suggest('Call /zzz', project: work), isEmpty);
    });

    test('`@` — метки, вставка тем же знаком', () {
      final items = suggest('Call @ur');
      expect(items.map((s) => s.insert), ['@urgent', '@ur']);
    });
  });

  test('подсветка неизвестного токена не появляется — разбор повторён', () {
    final r = resolver().resolve('Read #Books tomorrow', ctx);
    expect(r.unresolved, hasLength(1));
    expect(r.result.highlights.map((h) => h.kind), [HighlightKind.due]);
  });
}

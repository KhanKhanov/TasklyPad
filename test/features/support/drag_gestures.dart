import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/ui/drag_rows.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/tasks/ui/task_drag.dart';

// Помощники перетаскивания в тестах. Обычный `tester.drag` — это касание, а
// мышиный источник (ручка) принимает только мышь: жесты собираются из
// `startGesture` с нужным видом указателя.

/// Строка задачи с перетаскиванием по тексту названия.
Finder dragRow(String content) =>
    find.ancestor(of: find.text(content), matching: find.byType(TaskDragRow));

/// Мышь теста: одна на тест, чтобы второй жест не добавлял указатель снова.
final Expando<TestGesture> _mice = Expando('мышь теста');

/// Мышь над точкой [at]. Мышь живёт до конца теста.
Future<TestGesture> hoverAt(WidgetTester tester, Offset at) async {
  var mouse = _mice[tester];
  if (mouse == null) {
    mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    addTearDown(mouse.removePointer);
    _mice[tester] = mouse;
  }
  await mouse.moveTo(at);
  await tester.pump();
  return mouse;
}

/// Мышь над строкой [content]: ручка появляется.
Future<TestGesture> hoverRow(WidgetTester tester, String content) =>
    hoverAt(tester, tester.getCenter(dragRow(content)));

/// Центр ручки строки [content] (мышь должна быть над строкой).
Offset gripCenter(WidgetTester tester, String content) => tester.getCenter(
  find.descendant(of: dragRow(content), matching: find.byType(DragGrip)),
);

/// Шаги [from] → [to] указателем [gesture]: с паузой между шагами, чтобы
/// `DragTarget` и автопрокрутка успевали отреагировать.
Future<void> moveInSteps(
  WidgetTester tester,
  TestGesture gesture,
  Offset from,
  Offset to, {
  int steps = 8,
}) async {
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Взять ручку строки [content] мышью и довести до [to], не отпуская.
Future<TestGesture> startMouseDrag(
  WidgetTester tester,
  String content,
  Offset to, {
  int steps = 8,
}) async {
  final mouse = await hoverRow(tester, content);
  final from = gripCenter(tester, content);
  await mouse.moveTo(from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await moveInSteps(tester, mouse, from, to, steps: steps);
  return mouse;
}

/// Перетащить строку [content] за ручку на [to] и отпустить.
Future<void> mouseDrag(
  WidgetTester tester,
  String content,
  Offset to, {
  int steps = 8,
}) async {
  final mouse = await startMouseDrag(tester, content, to, steps: steps);
  await mouse.up();
  await tester.pumpAndSettle();
}

/// Взять строку [content] касанием: долгое нажатие, затем движение к [to].
Future<TestGesture> startLongPressDrag(
  WidgetTester tester,
  String content,
  Offset to, {
  int steps = 8,
}) async {
  final from = touchStart(tester, content);
  final touch = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await moveInSteps(tester, touch, from, to, steps: steps);
  return touch;
}

/// Перетащить строку [content] долгим нажатием на [to] и отпустить.
Future<void> longPressDrag(
  WidgetTester tester,
  String content,
  Offset to, {
  int steps = 8,
}) async {
  final touch = await startLongPressDrag(tester, content, to, steps: steps);
  await touch.up();
  await tester.pumpAndSettle();
}

/// Где у строки [content] стоит указатель при взятии за ручку (мышь) —
/// от этого X считается сдвиг уровня; у касания — [touchStart].
double gripX(WidgetTester tester, String content) =>
    tester.getRect(dragRow(content)).left + dragGutter / 2;

/// Точка касания строки [content] для долгого нажатия: на самой строке.
Offset touchStart(WidgetTester tester, String content) =>
    tester.getCenter(dragRow(content)) + const Offset(40, 0);

/// Нижняя половина строки [content] — линия под ней. [x] — X указателя
/// (по умолчанию как у ручки той же строки), [dx] — сдвиг уровня.
Offset belowHalf(
  WidgetTester tester,
  String content, {
  double? x,
  double dx = 0,
}) {
  final r = tester.getRect(dragRow(content));
  return Offset((x ?? r.left + dragGutter / 2) + dx, r.bottom - 6);
}

/// Верхняя половина строки [content] — линия над ней.
Offset aboveHalf(
  WidgetTester tester,
  String content, {
  double? x,
  double dx = 0,
}) {
  final r = tester.getRect(dragRow(content));
  return Offset((x ?? r.left + dragGutter / 2) + dx, r.top + 6);
}

/// Взять мышью всю строку (проект, метка: ручки нет) в точке [from] и довести
/// до [to], не отпуская.
Future<TestGesture> startMouseDragAt(
  WidgetTester tester,
  Offset from,
  Offset to, {
  int steps = 8,
}) async {
  final mouse = await hoverAt(tester, from);
  await mouse.down(from);
  await tester.pump();
  await moveInSteps(tester, mouse, from, to, steps: steps);
  return mouse;
}

/// Перетащить мышью из [from] в [to] и отпустить.
Future<void> mouseDragAt(
  WidgetTester tester,
  Offset from,
  Offset to, {
  int steps = 8,
}) async {
  final mouse = await startMouseDragAt(tester, from, to, steps: steps);
  await mouse.up();
  await tester.pumpAndSettle();
}

/// Долгое нажатие в [from] и перетаскивание касанием в [to].
Future<void> longPressDragAt(
  WidgetTester tester,
  Offset from,
  Offset to, {
  int steps = 8,
}) async {
  final touch = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await moveInSteps(tester, touch, from, to, steps: steps);
  await touch.up();
  await tester.pumpAndSettle();
}

/// Точка на виджете [finder] [dy] ниже его верха и [dx] правее левого края.
Offset inside(
  WidgetTester tester,
  Finder finder, {
  double dx = 60,
  double? dy,
}) {
  final r = tester.getRect(finder);
  return Offset(r.left + dx, dy == null ? r.center.dy : r.top + dy);
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';
import '../logic/due_dates.dart';

part 'today.g.dart';

/// Сегодняшняя дата устройства (полночь) для подписей срока — по стенным
/// часам (`AppClock.nowWall`), как разбор дат и расчёт повторений: иначе
/// «Сегодня» в строке и «today» в разборе могли бы разойтись. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».
@riverpod
DateTime today(Ref ref) {
  final now = ref.watch(clockProvider).nowWall();
  final day = DateTime(now.year, now.month, now.day);
  // Ждём до полуночи по стенным часам. В ночь перевода часов настоящий
  // промежуток на час длиннее или короче: сработали раньше — дата та же, и
  // таймер встаёт заново на остаток; позже — подпись отстаёт не больше часа.
  final midnight = DateTime.utc(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  return day;
}

/// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
/// просроченный (help «Introduction to dates and time»: зелёный — «haven't
/// gone past the due time»). Пересчитывается в момент срока: таймер стоит
/// только у сроков на сегодня со временем впереди.
@riverpod
bool dueTimePassed(Ref ref, String date, String time) {
  final today = ref.watch(todayProvider);
  final day = parseIsoDate(date);
  final parts = time.split(':');
  final (h, m) = parts.length == 2
      ? (int.tryParse(parts.first), int.tryParse(parts.last))
      : (null, null);
  if (day == null || day != today || h == null || m == null) return false;
  final now = ref.watch(clockProvider).nowWall();
  // Стенное время — в обёртке UTC, как у `nowWall`.
  final at = DateTime.utc(day.year, day.month, day.day, h, m);
  if (!now.isBefore(at)) return true;
  // Ждём по стенным часам, как [today]: в ночь перевода часов таймер
  // сработает на час раньше (и встанет заново) или позже. Пояс срока `tz`
  // не учитывается — время сравнивается по часам устройства (О-64).
  final timer = Timer(at.difference(now), ref.invalidateSelf);
  // Таймер на телефоне в глубоком сне стоит — как у [today].
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  return false;
}

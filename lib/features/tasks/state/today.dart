import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';

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

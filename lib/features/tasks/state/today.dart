import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';

part 'today.g.dart';

/// Сегодняшняя локальная дата (полночь) для подписей срока. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».
@riverpod
DateTime today(Ref ref) {
  final now = ref.watch(clockProvider).nowUtc().toLocal();
  final day = DateTime(now.year, now.month, now.day);
  var midnight = DateTime(now.year, now.month, now.day + 1);
  // В поясах, где часы переводят ровно в полночь, такой полночи нет и дата
  // может нормализоваться назад; тогда ждём час, а не перестраиваемся сразу.
  if (!midnight.isAfter(now)) midnight = now.add(const Duration(hours: 1));
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  return day;
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';
import '../../../domain/view_options.dart';

part 'view_options.g.dart';

/// «Отображение» всех видов — своё и пришедшее синхронизацией (О-22): одна
/// подписка на таблицу, живёт всё время работы приложения, поэтому при
/// повторном входе в вид его настройки уже готовы.
@Riverpod(keepAlive: true)
Stream<Map<(ViewType, String?), ViewOptions>> allViewOptions(Ref ref) =>
    ref.watch(viewOptionsRepositoryProvider).watchAll();

/// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
/// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
/// пробрасывается: правка от умолчаний вместо настоящих настроек записала
/// бы не то, что видел пользователь.
@riverpod
ViewOptions viewOptions(Ref ref, ViewType viewType, String? objectId) {
  final all = ref.watch(allViewOptionsProvider);
  if (all case AsyncError(:final error, :final stackTrace)) {
    Error.throwWithStackTrace(error, stackTrace);
  }
  return all.value?[(viewType, objectId)] ??
      ViewOptions(viewType: viewType, objectId: objectId);
}

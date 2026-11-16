import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';
import '../../../domain/search.dart';

part 'search_index.g.dart';

/// Свёрнутые тексты текущего снимка для окна «Поиск»; `null` — снимок ещё
/// грузится. Живёт, пока открыто окно (autoDispose): разбор markdown всех
/// задач не повторяется на каждую правку, когда окна нет.
@riverpod
SearchIndex? searchIndex(Ref ref) {
  final ws = ref.watch(workspaceProvider).value;
  return ws == null ? null : SearchIndex(ws);
}

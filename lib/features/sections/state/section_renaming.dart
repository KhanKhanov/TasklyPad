import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'section_renaming.g.dart';

/// Разделы, имя которых сейчас правят на месте: пока поле открыто, раздел не
/// перетаскивается (долгое нажатие в поле — выделение текста, а не перенос).
/// Состояние интерфейса этого устройства, не синхронизируется.
@Riverpod(keepAlive: true)
class SectionRenaming extends _$SectionRenaming {
  @override
  Set<String> build() => const {};

  /// Раздел [id] правят ([on]) или закончили.
  void set(String id, {required bool on}) {
    if (state.contains(id) == on) return;
    state = on ? {...state, id} : ({...state}..remove(id));
  }

  /// То же [set] с `on: false`, но когда провайдер мог уже закрыться
  /// (раздел убран вместе с экраном посреди правки).
  void stopIfMounted(String id) {
    if (ref.mounted) set(id, on: false);
  }
}

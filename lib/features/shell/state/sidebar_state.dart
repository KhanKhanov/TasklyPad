import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sidebar_state.g.dart';

/// Боковая панель открыта (на широком окне). Локальное состояние окна, не
/// данные пользователя: в журнал не пишется.
@Riverpod(keepAlive: true)
class SidebarOpen extends _$SidebarOpen {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

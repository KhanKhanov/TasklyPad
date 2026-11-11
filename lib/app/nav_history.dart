import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'router.dart';

part 'nav_history.g.dart';

/// История переходов между экранами за время работы приложения: `Alt+←` /
/// `Alt+→` — назад и вперёд (help «Use keyboard shortcuts»), боковые кнопки
/// мыши — то же, наше дополнение (решение 13А «M4.10a» plans/m4). У go_router есть только
/// «назад» по стеку маршрутов, а экраны оболочки сменяют друг друга через
/// `go`, поэтому историю ведём сами. Это состояние сеанса, а не данные
/// пользователя: не сохраняется и не синхронизируется.
class NavHistory {
  NavHistory({this.limit = 50});

  /// Сколько шагов назад помнить.
  final int limit;

  final List<String> _back = [];
  final List<String> _forward = [];
  String? _current;

  bool get canBack => _back.isNotEmpty;
  bool get canForward => _forward.isNotEmpty;

  /// Открыт экран [location] (адрес целиком, с параметрами). Тот же адрес —
  /// не шаг: так переход из [back] и [forward] не попадает в историю второй
  /// раз. Новый переход очищает «вперёд», как в браузере.
  void visit(String location) {
    if (location == _current) return;
    if (_current case final current?) {
      _back.add(current);
      if (_back.length > limit) _back.removeAt(0);
    }
    _forward.clear();
    _current = location;
  }

  /// Адрес шага назад или `null`, если идти некуда.
  String? back() {
    if (_back.isEmpty) return null;
    _forward.add(_current!);
    return _current = _back.removeLast();
  }

  /// Адрес шага вперёд или `null`.
  String? forward() {
    if (_forward.isEmpty) return null;
    _back.add(_current!);
    return _current = _forward.removeLast();
  }
}

/// История переходов приложения: следит за адресом роутера.
@Riverpod(keepAlive: true)
NavHistory navHistory(Ref ref) {
  final router = ref.watch(routerProvider);
  final history = NavHistory();
  final delegate = router.routerDelegate;
  void record() {
    final config = delegate.currentConfiguration;
    if (config.isNotEmpty) history.visit(config.uri.toString());
  }

  delegate.addListener(record);
  ref.onDispose(() => delegate.removeListener(record));
  record();
  return history;
}

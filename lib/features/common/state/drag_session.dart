import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drag_session.g.dart';

/// Как показано место броска: линия над или под строкой, рамка вокруг
/// заголовка и пункта сайдбара.
enum DropMark { above, below, frame }

/// Где и как нарисовать место броска. Сравнивается по значению: сессия
/// меняется, только когда место сменилось, и строки списка не перестраиваются
/// на каждое движение мыши.
@immutable
final class DropIndicator {
  const DropIndicator({
    required this.owner,
    required this.mark,
    this.indent = 0,
    this.caption,
  });

  /// Кто рисует: id задачи, `project:<id>`, `day:<дата>` и т. п.
  final Object owner;
  final DropMark mark;

  /// Отступ линии слева — уровень, на котором встанет задача.
  final double indent;

  /// Подпись у линии («Завтра»): куда на самом деле встанет задача, когда
  /// линия стоит не там.
  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is DropIndicator &&
      other.owner == owner &&
      other.mark == mark &&
      other.indent == indent &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(owner, mark, indent, caption);
}

/// Идущее перетаскивание: что тащат и куда бросят бы сейчас.
@immutable
final class DragSessionState {
  const DragSessionState({this.sources = const {}, this.indicator});

  /// Id перетаскиваемых элементов — их строки бледнеют.
  final Set<String> sources;
  final DropIndicator? indicator;

  @override
  bool operator ==(Object other) =>
      other is DragSessionState &&
      setEquals(other.sources, sources) &&
      other.indicator == indicator;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(sources), indicator);
}

/// Сессия перетаскивания (состояние интерфейса этого устройства, не
/// синхронизируется): `null` — ничего не тащат. Строки читают её через
/// `select`, поэтому каждая перестраивается, только когда её это касается.
@Riverpod(keepAlive: true)
class DragSession extends _$DragSession {
  @override
  DragSessionState? build() => null;

  /// Тащат [sources], бросок — на [indicator] (`null` — места нет).
  void update(Set<String> sources, DropIndicator? indicator) {
    final next = DragSessionState(sources: sources, indicator: indicator);
    if (state != next) state = next;
  }

  /// Перетаскивание закончено или отменено.
  void clear() {
    if (state != null) state = null;
  }

  /// То же, но после того как провайдер мог быть закрыт (слой перетаскивания
  /// снят вместе с окном, пока шло перетаскивание).
  void clearIfMounted() {
    if (ref.mounted) clear();
  }
}

import 'dart:async';

import 'package:planner/platform/conflict_notifier.dart';

/// Уведомления ОС без ОС: окно «активно», пока [active]; показанные —
/// в [shown]; клик — [open].
final class FakeConflictNotifier implements ConflictNotifier {
  bool active = true;
  final List<({String title, String body})> shown = [];
  final StreamController<void> _opened = StreamController.broadcast();

  void open() => _opened.add(null);

  @override
  Future<void> start() async {}

  @override
  Future<bool> isAppActive() async => active;

  @override
  Future<void> show({required String title, required String body}) async =>
      shown.add((title: title, body: body));

  @override
  Stream<void> get opened => _opened.stream;
}

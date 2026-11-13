import 'package:flutter/widgets.dart';

/// Закрыть окно, в котором стоит [context], — даже если поверх него уже
/// открыто другое: `Navigator.pop` снял бы верхнее, чужое окно. Так окно,
/// которое закрывается само (задачу удалили, карточек не осталось), не
/// закрывает вместо себя подтверждение или окно карточек конфликта (ревью 1Б
/// M4.13). Окно уже закрыто — ничего не делает.
void closeOwnRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

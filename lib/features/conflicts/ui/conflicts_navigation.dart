import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Путь экрана «Конфликты».
const String conflictsPath = '/conflicts';

/// «Конфликты» открываются поверх текущего экрана (`push`), а не вместо него:
/// «Назад» и `Esc` возвращают туда, откуда пришли. Уже открытые второй раз
/// не кладутся.
void showConflictsScreen(GoRouter router) {
  if (router.routerDelegate.currentConfiguration.uri.path == conflictsPath) {
    return;
  }
  unawaited(router.push<void>(conflictsPath));
}

/// Вернуться на экран, с которого открыли «Конфликты»; открыли по ссылке
/// без предыдущего экрана — во «Входящие».
void closeConflictsScreen(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go('/');
  }
}

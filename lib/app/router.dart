import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/views/inbox/ui/inbox_screen.dart';

part 'router.g.dart';

/// Маршруты приложения. Deep links из уведомлений и виджетов ведут сюда же.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'inbox',
        builder: (context, state) => const InboxScreen(),
      ),
    ],
  );
}

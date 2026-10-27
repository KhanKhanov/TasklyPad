import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/labels/ui/filters_labels_screen.dart';
import '../features/labels/ui/label_screen.dart';
import '../features/projects/ui/project_screen.dart';
import '../features/projects/ui/projects_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/shell/ui/app_shell.dart';

part 'router.g.dart';

/// Маршруты приложения. Deep links из уведомлений и виджетов ведут сюда же.
/// Все экраны — внутри [AppShell] (`ShellRoute`): сайдбар не пересоздаётся
/// при переходах.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'inbox',
            builder: (context, state) => const ProjectScreen(),
          ),
          GoRoute(
            path: '/project/:id',
            name: 'project',
            builder: (context, state) =>
                ProjectScreen(projectId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/filters-labels',
            name: 'filtersLabels',
            builder: (context, state) => const FiltersLabelsScreen(),
          ),
          GoRoute(
            path: '/label/:id',
            name: 'label',
            builder: (context, state) =>
                LabelScreen(labelId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

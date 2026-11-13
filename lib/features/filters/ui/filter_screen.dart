import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/conflicts.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/filter_query.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/filter_parser.dart';
import '../../common/ui/description_line.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../conflicts/ui/conflict_mark.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_order.dart';
import '../../views/state/view_options.dart';
import '../../views/ui/view_options_button.dart';
import '../../views/ui/view_sort_keys.dart';
import 'filter_dialog.dart';
import 'filter_lists.dart';
import 'filter_menu.dart';
import 'filter_query_field.dart';

/// Экран фильтра (help «Introduction to filters»): название, описание под ним
/// над результатами, списки по частям запроса — только активные задачи, у
/// каждой проект и раздел. Порядок — по умолчанию фильтра (О-85) или
/// сортировка «Отображения»; вручную не упорядочивается (help «Sort or group
/// tasks»). Запрос разбирается заново при каждой перестройке: даты в нём —
/// от сегодняшнего дня. Запрос с ошибкой (пришёл с другого устройства) —
/// текст ошибки и «Изменить фильтр».
class FilterScreen extends ConsumerWidget {
  const FilterScreen({super.key, required this.filterId});

  final String filterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      WorkspaceView(builder: (context, ws) => _build(context, ref, ws));

  Widget _build(BuildContext context, WidgetRef ref, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final filter = ws.filter(filterId);
    final inbox = ws.inbox;
    if (filter == null || inbox == null) {
      return Center(child: Text(l10n.rejectNotFound));
    }
    final options = ref.watch(viewOptionsProvider(ViewType.filter, filterId));
    // Подписка: «сегодня» в запросе и группы по дням меняются в полночь.
    ref.watch(todayProvider);
    final (shown, error) = _evaluate(ref, filter, ws, options);
    return ViewSortKeys(
      viewType: ViewType.filter,
      objectId: filter.id,
      child: Focus(
        autofocus: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: TaskOrderScope(
              // Порядок — на момент открытия панели, по свежему снимку.
              order: (ws) => _order(ref, ws),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
                children: [
                  _Header(filter: filter),
                  ConflictBanner(
                    entity: ConflictEntity.filter,
                    id: filter.id,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  // Ключ по фильтру: экран тот же при переходе на другой
                  // фильтр, черновик не должен уйти в него.
                  DescriptionLine(
                    key: ValueKey(filter.id),
                    text: filter.description,
                    readOnly: false,
                    placeholder: l10n.addProjectDescription,
                    onSave: (text) => ref
                        .read(filterCommandsProvider)
                        .setDescription(filter.id, text),
                  ),
                  if (shown != null)
                    FilterLists(
                      lists: shown,
                      ws: ws,
                      inboxId: inbox.id,
                      grouping: options.grouping,
                    )
                  else if (error != null)
                    _Broken(filter: filter, error: error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Списки запроса фильтра на сейчас или ошибка его разбора.
  static (List<FilterList>?, FilterSyntaxError?) _evaluate(
    WidgetRef ref,
    SavedFilter filter,
    Workspace ws,
    ViewOptions options,
  ) {
    final now = ref.read(clockProvider).nowWall();
    try {
      final lists = evaluateFilter(
        ws,
        parseFilterQuery(filter.query, now: now),
        now: now,
        sorting: options.sorting,
        sortOrder: options.sortOrder,
      );
      return (lists, null);
    } on FilterSyntaxError catch (e) {
      return (null, e);
    }
  }

  List<String> _order(WidgetRef ref, Workspace ws) {
    final filter = ws.filter(filterId);
    if (filter == null) return const [];
    final options = ref.read(viewOptionsProvider(ViewType.filter, filterId));
    final (lists, _) = _evaluate(ref, filter, ws, options);
    return lists == null
        ? const []
        : filterOrder(
            ws,
            lists,
            options.grouping,
            today: ref.read(todayProvider),
            clock: ref.read(clockProvider),
          );
  }
}

/// Название фильтра, «Отображение» и меню «⋯».
class _Header extends StatelessWidget {
  const _Header({required this.filter});

  final SavedFilter filter;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              filter.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ViewOptionsButton(viewType: ViewType.filter, objectId: filter.id),
          FilterMenuButton(filter: filter, size: 22, selectTasks: true),
        ],
      ),
    );
  }
}

/// Запрос не разбирается: текст ошибки и «Изменить фильтр».
class _Broken extends StatelessWidget {
  const _Broken({required this.filter, required this.error});

  final SavedFilter filter;
  final FilterSyntaxError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            l10n.filterBroken,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filterErrorText(l10n, filter.query, error),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.danger),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showFilterDialog(context, filter: filter),
            child: Text(l10n.editFilter),
          ),
        ],
      ),
    );
  }
}

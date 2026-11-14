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
import '../../shell/ui/shell_keys.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_order.dart';
import '../../views/state/view_options.dart';
import '../../views/ui/view_options_button.dart';
import '../../views/ui/view_sort_keys.dart';
import '../logic/filter_add_values.dart';
import 'filter_dialog.dart';
import 'filter_lists.dart';
import 'filter_menu.dart';
import 'filter_query_field.dart';
import '../../views/logic/view_filter_apply.dart';

/// Экран фильтра (help «Introduction to filters»): название, описание под ним
/// над результатами, списки по частям запроса — только активные задачи, у
/// каждой проект и раздел. Порядок — по умолчанию фильтра (О-85) или
/// сортировка «Отображения»; вручную не упорядочивается (help «Sort or group
/// tasks»). Запрос разбирается заново при каждой перестройке: даты в нём —
/// от сегодняшнего дня. Запрос с ошибкой (пришёл с другого устройства) —
/// текст ошибки и «Изменить фильтр». «Добавить задачу» у каждого списка — со
/// значениями его части (решение 1А plans/m5); `a` / `Shift+A` — у первого.
class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key, required this.filterId});

  final String filterId;

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  /// Список, где открыт редактор «Добавить задачу», и его место.
  FilterAdding _adding = (list: 0, at: AddTaskAt.none);

  /// Задачи, подзадачи которых раскрыты на этом экране (решение 2А).
  final Set<String> _expanded = {};

  /// Запрос, по которому открыт редактор: части другого запроса — другие
  /// списки, и номер списка в [_adding] указывал бы не туда.
  String? _query;

  void _add(int list, AddTaskAt at) =>
      setState(() => _adding = (list: list, at: at));

  void _toggle(String id) => setState(
    () => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id),
  );

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final filter = ws.filter(widget.filterId);
    final inbox = ws.inbox;
    if (filter == null || inbox == null) {
      return Center(child: Text(l10n.rejectNotFound));
    }
    final options = ref.watch(
      viewOptionsProvider(ViewType.filter, widget.filterId),
    );
    // Подписка: «сегодня» в запросе и группы по дням меняются в полночь.
    ref.watch(todayProvider);
    if (_query != filter.query) {
      _adding = (list: 0, at: AddTaskAt.none);
      _query = filter.query;
    }
    final (shown, error) = _evaluate(filter, ws, options);
    return ViewSortKeys(
      viewType: ViewType.filter,
      objectId: filter.id,
      child: Shortcuts(
        shortcuts: projectShortcuts,
        child: Actions(
          actions: {
            AddTaskBottomIntent: HotkeyAction<AddTaskBottomIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => _add(0, AddTaskAt.bottom),
            ),
            AddTaskTopIntent: HotkeyAction<AddTaskTopIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => _add(0, AddTaskAt.top),
            ),
          },
          child: Focus(
            autofocus: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: TaskOrderScope(
                  // Порядок — на момент открытия панели, по свежему снимку.
                  order: _order,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
                    children: [
                      _Header(filter: filter),
                      ConflictBanner(
                        entity: ConflictEntity.filter,
                        id: filter.id,
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      DescriptionLine(
                        text: filter.description,
                        readOnly: false,
                        placeholder: l10n.addProjectDescription,
                        onSave: (text) => ref
                            .read(filterCommandsProvider)
                            .setDescription(filter.id, text),
                      ),
                      if (shown != null)
                        FilterLists(
                          // Другой запрос — другие списки: редактор группы
                          // (состояние списка) в них не переходит.
                          key: ValueKey(filter.query),
                          lists: shown.lists,
                          values: shown.values,
                          ws: ws,
                          inboxId: inbox.id,
                          grouping: options.grouping,
                          adding: _adding,
                          onAdd: _add,
                          expanded: _expanded,
                          onToggle: _toggle,
                        )
                      else if (error != null)
                        _Broken(filter: filter, error: error),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Списки запроса фильтра на сейчас и значения новой задачи каждого или
  /// ошибка разбора.
  (_Shown?, FilterSyntaxError?) _evaluate(
    SavedFilter filter,
    Workspace ws,
    ViewOptions options,
  ) {
    final now = ref.read(clockProvider).nowWall();
    try {
      final query = parseFilterQuery(filter.query, now: now);
      final lists = evaluateFilter(
        ws,
        query,
        now: now,
        sorting: options.sorting,
        sortOrder: options.sortOrder,
      );
      final values = [for (final p in query.parts) filterAddValues(ws, p.node)];
      // Фильтр «Отображения» поверх запроса (решение 3А plans/m5).
      final test = viewFilterTest(ws, options, now: now);
      final shown = test == null
          ? lists
          : [
              for (final l in lists)
                FilterList(l.title, l.tasks.where(test).toList(), l.order),
            ];
      return ((lists: shown, values: values), null);
    } on FilterSyntaxError catch (e) {
      return (null, e);
    }
  }

  List<String> _order(Workspace ws) {
    final filter = ws.filter(widget.filterId);
    if (filter == null) return const [];
    final options = ref.read(
      viewOptionsProvider(ViewType.filter, widget.filterId),
    );
    final (shown, _) = _evaluate(filter, ws, options);
    return shown == null
        ? const []
        : filterOrder(
            ws,
            shown.lists,
            options.grouping,
            expanded: _expanded,
            today: ref.read(todayProvider),
            clock: ref.read(clockProvider),
          );
  }
}

/// Списки фильтра и значения новой задачи каждого.
typedef _Shown = ({List<FilterList> lists, List<FilterAddValues> values});

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/shielded_menu_anchor.dart';
import '../../common/ui/ui_kit.dart';
import '../state/view_options.dart';

/// Кнопка «Отображение» в заголовке вида: группировка, сортировка с
/// направлением, «Выполненные задачи», «Сбросить всё» (help «Sort or group
/// tasks», решение 2 плана M4). Выбранные сортировка и группировка — числом
/// в кружке рядом с названием кнопки (решение 10Б M4.10a).
class ViewOptionsButton extends ConsumerWidget {
  const ViewOptionsButton({super.key, required this.viewType, this.objectId});

  final ViewType viewType;

  /// Проект или метка; у «Сегодня» и «Предстоящего» — `null`.
  final String? objectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final options = ref.watch(viewOptionsProvider(viewType, objectId));
    void save(ViewOptions next) => runCommand(
      context,
      () => ref.read(viewOptionsCommandsProvider).save(options, next),
    );

    Widget choice<T>(T value, T current, String text, ValueChanged<T> pick) =>
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 18,
            child: value == current
                ? Icon(Icons.check, size: 18, color: palette.accent)
                : null,
          ),
          onPressed: value == current ? null : () => pick(value),
          child: Text(text),
        );

    Widget submenu(String title, String value, List<Widget> children) =>
        SubmenuButton(
          menuChildren: children,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              const SizedBox(width: 16),
              Text(value, style: TextStyle(color: palette.textSecondary)),
            ],
          ),
        );

    final groupings = _groupings(viewType);
    final sortings = _sortings(viewType);
    // «Вручную» там, где это не отдельный выбор (из импорта Todoist), — тот
    // же порядок вида.
    final sorting = sortings.contains(options.sorting)
        ? options.sorting
        : Sorting.byDefault;
    return ShieldedMenuAnchor(
      menuChildren: [
        if (groupings.length > 1)
          submenu(l10n.viewGrouping, _groupingText(l10n, options.grouping), [
            for (final g in groupings)
              choice(
                g,
                options.grouping,
                _groupingText(l10n, g),
                (g) => save(options.copyWith(grouping: g)),
              ),
          ]),
        submenu(l10n.viewSorting, _sortingText(l10n, viewType, sorting), [
          for (final s in sortings)
            choice(
              s,
              sorting,
              _sortingText(l10n, viewType, s),
              (s) => save(options.copyWith(sorting: s)),
            ),
        ]),
        if (sorting.hasDirection)
          submenu(l10n.viewDirection, _orderText(l10n, options.sortOrder), [
            for (final o in SortOrder.values)
              choice(
                o,
                options.sortOrder,
                _orderText(l10n, o),
                (o) => save(options.copyWith(sortOrder: o)),
              ),
          ]),
        CheckboxMenuButton(
          value: options.showCompletedTasks,
          onChanged: (v) =>
              save(options.copyWith(showCompletedTasks: v ?? false)),
          child: Text(l10n.completedTasks),
        ),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: options.applied == 0
              ? null
              : () => runCommand(
                  context,
                  () => ref.read(viewOptionsCommandsProvider).resetAll(options),
                ),
          child: Text(l10n.viewResetAll),
        ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        // Экранный чтец и тесты видят «Отображение: N», хотя на экране —
        // «Отображение» и число в кружке.
        label: options.applied == 0
            ? l10n.viewOptions
            : l10n.viewOptionsCount(options.applied),
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 18, color: palette.textSecondary),
                const SizedBox(width: 4),
                Text(
                  l10n.viewOptions,
                  style: TextStyle(color: palette.textSecondary),
                ),
                if (options.applied > 0) ...[
                  const SizedBox(width: 6),
                  _CountBadge(count: options.applied),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Число изменённых настроек в круге цвета акцента (решение 10Б M4.10a; в
/// Todoist — оранжевая точка).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      key: const ValueKey('viewOptionsBadge'),
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
      child: Text(
        '$count',
        style: TextStyle(
          color:
              ThemeData.estimateBrightnessForColor(palette.accent) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Группировки вида: у «Предстоящего» их нет, «Проект» — вне проекта
/// (решение 2 плана M4); фильтр — M5. У подзадач панели «Отображения» нет.
List<Grouping> _groupings(ViewType type) => switch (type) {
  ViewType.upcoming || ViewType.task => const [Grouping.none],
  ViewType.project => [
    for (final g in Grouping.values)
      if (g != Grouping.project) g,
  ],
  ViewType.today || ViewType.label || ViewType.filter => Grouping.values,
};

String _groupingText(AppLocalizations l10n, Grouping g) => switch (g) {
  Grouping.none => l10n.groupingNone,
  Grouping.dueDate => l10n.viewByDate,
  Grouping.addedDate => l10n.viewByAddedDate,
  Grouping.deadline => l10n.fieldDeadline,
  Grouping.priority => l10n.fieldPriority,
  Grouping.label => l10n.viewByLabel,
  Grouping.project => l10n.fieldProject,
};

/// Сортировки вида, порядок вида первым. «Вручную» отдельным пунктом — только
/// в «Сегодня» и «Предстоящем», где по умолчанию умный порядок (help «Default
/// sorting order»: «Smart sorted by default… You can turn on Manual
/// sorting»; решение 1А «Ход M4.6»); в проекте ручной порядок и есть
/// умолчание, у метки и фильтра его нет (help «Sort or group tasks»).
List<Sorting> _sortings(ViewType type) => [
  for (final s in Sorting.values)
    if (s != Sorting.manual ||
        type == ViewType.today ||
        type == ViewType.upcoming)
      s,
];

/// Порядок вида по умолчанию: в проекте — «Вручную», в «Сегодня» и
/// «Предстоящем» — «Умная», у метки и фильтра — «По умолчанию».
String _sortingText(AppLocalizations l10n, ViewType type, Sorting s) =>
    switch (s) {
      Sorting.byDefault => switch (type) {
        ViewType.label || ViewType.filter => l10n.sortingDefault,
        ViewType.project || ViewType.task => l10n.sortingManual,
        ViewType.today || ViewType.upcoming => l10n.sortingSmart,
      },
      Sorting.manual => l10n.sortingManual,
      Sorting.alphabetically => l10n.viewByName,
      Sorting.dueDate => l10n.viewByDate,
      Sorting.addedDate => l10n.viewByAddedDate,
      Sorting.deadline => l10n.fieldDeadline,
      Sorting.priority => l10n.fieldPriority,
    };

String _orderText(AppLocalizations l10n, SortOrder o) => switch (o) {
  SortOrder.asc => l10n.sortAscending,
  SortOrder.desc => l10n.sortDescending,
};

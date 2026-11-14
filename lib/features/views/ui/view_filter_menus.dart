import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/text_fold.dart';
import '../../../domain/view_filter.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';

/// Подменю фильтра «Отображения» (help «Customize views»: Date, Deadline,
/// Priority, Label; исполнитель и рабочее пространство — вне scope, §11):
/// в каждом один выбор или «Все» (решение 3А plans/m5). Выбор пишется в
/// `filtered_by` через [save] запросом ([ViewFilter.query]).
List<Widget> viewFilterMenus(
  BuildContext context, {
  required ViewOptions options,
  required List<Label> labels,
  required ValueChanged<ViewOptions> save,
}) {
  final l10n = AppLocalizations.of(context);
  final palette = AppPalette.of(context);
  final filter = ViewFilter.parse(options.filteredBy);
  void pick(ViewFilter next) => save(options.copyWith(filteredBy: next.query));

  Widget choice(bool checked, String text, VoidCallback onPick) =>
      MenuItemButton(
        leadingIcon: SizedBox(
          width: 18,
          child: checked
              ? Icon(Icons.check, size: 18, color: palette.accent)
              : null,
        ),
        onPressed: checked ? null : onPick,
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

  String dateText(ViewDateChoice? c, {required bool deadline}) => switch (c) {
    null => l10n.viewFilterAll,
    ViewDateChoice.today => l10n.todayView,
    ViewDateChoice.thisWeek => l10n.viewFilterThisWeek,
    ViewDateChoice.next7Days => l10n.viewFilterNext7Days,
    ViewDateChoice.thisMonth => l10n.viewFilterThisMonth,
    ViewDateChoice.next30Days => l10n.viewFilterNext30Days,
    ViewDateChoice.none =>
      deadline ? l10n.viewFilterNoDeadline : l10n.viewFilterNoDate,
  };

  List<Widget> dates(
    ViewDateChoice? current,
    ViewFilter Function(ViewDateChoice?) next, {
    required bool deadline,
  }) => [
    for (final c in <ViewDateChoice?>[null, ...ViewDateChoice.values])
      choice(
        c == current,
        dateText(c, deadline: deadline),
        () => pick(next(c)),
      ),
  ];

  // Метка из запроса, которой уже нет (переименована), — тоже в списке,
  // отмеченной: иначе выбор было бы не увидеть.
  final label = filter.label;
  final known =
      label == null || labels.any((l) => foldText(l.name) == foldText(label));
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        l10n.viewFilterHeader,
        style: TextStyle(color: palette.textSecondary, fontSize: 12),
      ),
    ),
    submenu(
      l10n.viewFilterDate,
      dateText(filter.date, deadline: false),
      dates(filter.date, filter.withDate, deadline: false),
    ),
    submenu(
      l10n.fieldDeadline,
      dateText(filter.deadline, deadline: true),
      dates(filter.deadline, filter.withDeadline, deadline: true),
    ),
    submenu(
      l10n.fieldPriority,
      filter.priority == null
          ? l10n.viewFilterAll
          : l10n.priorityN(filter.priority!),
      [
        for (final p in <int?>[null, 1, 2, 3, 4])
          choice(
            p == filter.priority,
            p == null ? l10n.viewFilterAll : l10n.priorityN(p),
            () => pick(filter.withPriority(p)),
          ),
      ],
    ),
    submenu(l10n.viewByLabel, label ?? l10n.viewFilterAll, [
      choice(
        label == null,
        l10n.viewFilterAll,
        () => pick(filter.withLabel(null)),
      ),
      if (!known) choice(true, label, () {}),
      for (final l in labels)
        choice(
          label != null && foldText(l.name) == foldText(label),
          l.name,
          () => pick(filter.withLabel(l.name)),
        ),
    ]),
  ];
}

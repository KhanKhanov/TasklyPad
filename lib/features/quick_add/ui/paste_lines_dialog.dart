import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Ответ на «Добавить X задач?».
enum PasteChoice {
  /// «Добавить 1 задачу»: строки — одна задача, через пробел.
  one,

  /// «Добавить X задач»: каждая строка — задача.
  all,
}

/// Окно вставки нескольких строк, как в Todoist на компьютере (help «Add or
/// manage multiple tasks»): «Отмена», «Добавить 1 задачу», «Добавить X
/// задач». `null` — отмена.
Future<PasteChoice?> confirmPasteLines(BuildContext context, int count) {
  final l10n = AppLocalizations.of(context);
  return showDialog<PasteChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.pasteTasksTitle(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, PasteChoice.one),
          child: Text(l10n.pasteTasksOne),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, PasteChoice.all),
          child: Text(l10n.pasteTasksAll(count)),
        ),
      ],
    ),
  );
}

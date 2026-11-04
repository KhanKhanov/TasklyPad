import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';
import 'view_options_button.dart';

// Общие части экранов «Сегодня» и «Предстоящее».

/// Заголовок вида: название и «Отображение».
class ViewHeader extends StatelessWidget {
  const ViewHeader({super.key, required this.title, required this.viewType});

  final String title;
  final ViewType viewType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppPalette.of(context).textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ViewOptionsButton(viewType: viewType),
      ],
    ),
  );
}

/// Заголовок дня в списке: «4 нояб. · Сегодня · среда».
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      height: 40,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Пустой вид — «Пока нет задач».
class ViewEmpty extends StatelessWidget {
  const ViewEmpty({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Text(
      AppLocalizations.of(context).inboxEmpty,
      textAlign: TextAlign.center,
      style: TextStyle(color: AppPalette.of(context).textSecondary),
    ),
  );
}

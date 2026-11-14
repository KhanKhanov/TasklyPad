import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/filter_query.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/filter_parser.dart';
import '../../common/ui/app_switch.dart';
import '../../common/ui/text_limit.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/state/today.dart';
import 'filter_query_field.dart';

/// Окно «Добавить фильтр» / «Изменить фильтр» (help «Introduction to
/// filters»): название, запрос, цвет, «Добавить в избранное». Описания здесь
/// нет — оно у существующего фильтра, под именем на его экране (help). Запрос
/// разбирается при вводе: ошибка подсвечена, сохранить нельзя (решение
/// M5.2: синтаксис проверяет окно, а не команда).
Future<void> showFilterDialog(BuildContext context, {SavedFilter? filter}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _FilterDialog(filter: filter),
    );

class _FilterDialog extends ConsumerStatefulWidget {
  const _FilterDialog({this.filter});

  final SavedFilter? filter;

  @override
  ConsumerState<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<_FilterDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.filter?.name ?? '',
  );
  late final FilterQueryController _query = FilterQueryController(
    text: widget.filter?.query ?? '',
  );
  late String _color = widget.filter?.color ?? 'charcoal';
  late bool _favorite = widget.filter?.isFavorite ?? false;

  /// Разобранный запрос; `null` — пустой или с ошибкой.
  FilterQuery? _parsed;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Разбор запроса на текущий момент: даты в нём — от «сейчас».
  void _parse() {
    final text = _query.text;
    if (text.trim().isEmpty) {
      _parsed = null;
      _query.error = null;
      return;
    }
    try {
      _parsed = parseFilterQuery(text, now: ref.read(clockProvider).nowWall());
      _query.error = null;
    } on FilterSyntaxError catch (e) {
      _parsed = null;
      _query.error = e;
    }
  }

  bool get _canSave =>
      !_busy && _name.text.trim().isNotEmpty && _parsed != null;

  Future<void> _save() async {
    if (!_canSave) return; // повторный Enter или ошибка в запросе
    setState(() => _busy = true);
    final commands = ref.read(filterCommandsProvider);
    final l10n = AppLocalizations.of(context);
    final filter = widget.filter;
    try {
      if (filter == null) {
        await commands.add(
          name: _name.text,
          query: _query.text,
          color: _color,
          isFavorite: _favorite,
        );
      } else {
        // Только изменённые поля: нетронутое поле со старым значением
        // затёрло бы правку, пришедшую с другого устройства.
        await commands.edit(
          filter.id,
          name: _name.text.trim() != filter.name ? _name.text : null,
          query: _query.text.trim() != filter.query ? _query.text : null,
          color: _color != filter.color ? _color : null,
          isFavorite: _favorite != filter.isFavorite ? _favorite : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } on CommandRejected catch (e) {
      if (mounted) setState(() => _error = rejectMessage(l10n, e.reason));
    } on Exception catch (e, stackTrace) {
      logCommandError(e, stackTrace);
      if (mounted) setState(() => _error = l10n.actionFailed('$e'));
    } finally {
      // И при ошибке программы кнопка не остаётся заблокированной.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.filter != null;
    // Новый день — «today» в запросе другой: разобрать заново.
    ref.listen(todayProvider, (_, _) => setState(_parse));
    final ws = ref.watch(workspaceProvider).value;
    final parsed = _parsed;
    final lists = parsed == null || ws == null
        ? null
        : evaluateFilter(ws, parsed, now: ref.read(clockProvider).nowWall());
    return AlertDialog(
      title: Text(editing ? l10n.editFilter : l10n.addFilter),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: Limits.filterName,
                inputFormatters: const [TextLimit(Limits.filterName)],
                decoration: InputDecoration(
                  labelText: l10n.fieldName,
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              FilterQueryField(
                controller: _query,
                lists: lists,
                onChanged: (_) => setState(() {
                  _error = null;
                  _parse();
                }),
                onSubmitted: _save,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _color,
                decoration: InputDecoration(labelText: l10n.fieldColor),
                items: [
                  for (final key in projectColors.keys)
                    DropdownMenuItem(
                      value: key,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: projectColor(key),
                          ),
                          const SizedBox(width: 10),
                          Text(colorName(l10n, key)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _color = v ?? _color),
              ),
              const SizedBox(height: 8),
              AppSwitchTile(
                value: _favorite,
                title: Text(l10n.addToFavorites),
                onChanged: (v) => setState(() => _favorite = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(editing ? l10n.actionSave : l10n.actionAdd),
          ),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/recently_viewed.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/filter_query.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/search.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/text_limit.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/logic/shell_commands.dart';
import '../../shell/ui/shell_command_texts.dart';
import '../logic/search_input.dart';
import '../logic/search_items.dart';
import '../state/search_index.dart';
import 'search_actions.dart';
import 'search_list.dart';
import 'search_tabs.dart';
import 'search_tiles.dart';

/// Окно «Поиск» (help «Introduction to search»; решения 1А–3А plans/m5
/// «Решения M5.4»): `/`, `f`, `Ctrl+F`, `Ctrl+K` и пункт сайдбара. На
/// компьютере — окно сверху поверх приложения, на телефоне — весь экран.
/// [context] — оболочки: в нём открываются экраны и окна после закрытия
/// поиска; [run] — её команды.
Future<void> showSearchWindow(
  BuildContext context, {
  required ValueChanged<ShellCommandId> run,
}) {
  final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
  final actions = SearchActions(shell: context, run: run);
  return showDialog<void>(
    context: context,
    builder: (dialog) => wide
        ? Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: AppPalette.of(dialog).background,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 640,
                    maxHeight: MediaQuery.sizeOf(dialog).height * 0.7,
                  ),
                  child: SearchWindow(actions: actions, showKeys: true),
                ),
              ),
            ),
          )
        : Dialog.fullscreen(
            backgroundColor: AppPalette.of(dialog).background,
            child: SafeArea(
              child: SearchWindow(actions: actions, showKeys: false),
            ),
          ),
  );
}

/// Содержимое окна «Поиск»: строка, вкладки, строки результатов; ↑/↓ —
/// выбор строки, Enter — открыть, Esc — закрыть.
class SearchWindow extends ConsumerStatefulWidget {
  const SearchWindow({
    super.key,
    required this.actions,
    required this.showKeys,
  });

  final SearchActions actions;

  /// Подсказки клавиш у команд — на компьютере.
  final bool showKeys;

  @override
  ConsumerState<SearchWindow> createState() => _SearchWindowState();
}

class _SearchWindowState extends ConsumerState<SearchWindow> {
  final TextEditingController _text = TextEditingController();
  SearchTab _tab = SearchTab.top;
  bool _completed = false;
  int _selected = -1;
  List<SearchItem> _items = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _completed = false;
    _tab = SearchTab.top;
    _selected = _text.text.trim().isEmpty ? -1 : 0;
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (step != 0 && _items.isNotEmpty) {
      setState(
        () => _selected = (_selected + step).clamp(0, _items.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _activateSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activateSelected() {
    if (_selected >= 0 && _selected < _items.length) {
      _activate(_items[_selected]);
    }
  }

  void _activate(SearchItem item) {
    switch (item) {
      case RecentSearchRow(:final text):
        // Курсор — в конец: сеттер `text` оставил бы выделение неопределённым.
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _changed(text);
      case SearchCompletedRow():
        setState(() {
          _completed = true;
          _tab = SearchTab.tasks;
        });
      default:
        widget.actions.activate(context, ref, item, _text.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ws = ref.watch(workspaceProvider).value;
    final index = ref.watch(searchIndexProvider);
    final recent = ref.watch(recentSearchesProvider).value ?? const [];
    final viewed =
        ref.watch(recentlyViewedControllerProvider).value?.items ?? const [];
    final input = classifySearch(
      _text.text,
      now: ref.read(clockProvider).nowWall(),
    );
    final results = switch (input) {
      WordSearch(:final query) when index != null => index.search(query),
      _ => SearchResults.empty,
    };
    final tabs = [
      for (final t in SearchTab.values)
        if (results.of(t).isNotEmpty) t,
    ];
    final tab = tabs.contains(_tab) ? _tab : (tabs.firstOrNull ?? _tab);
    final hits = switch (input) {
      WordSearch() => results.of(tab),
      FilterSearch(:final query) when ws != null => _filterHits(ws, query),
      _ => const <SearchHit>[],
    };
    final completed = switch (input) {
      WordSearch(:final query) when _completed && index != null =>
        index.completed(query),
      _ => const <Task>[],
    };
    _items = ws == null
        ? const []
        : searchItems(
            input: input,
            recent: recent,
            viewed: [
              for (final v in viewed)
                if (viewedAlive(ws, v)) v,
            ],
            commands: paletteCommands(
              input,
              (id) => shellCommandLabel(l10n, id),
            ),
            hits: hits,
            completed: completed,
            canSearchCompleted: input is WordSearch && !_completed,
          );
    final empty =
        input is! EmptySearch &&
        hits.isEmpty &&
        results.isEmpty &&
        completed.isEmpty;
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _text,
              autofocus: true,
              maxLength: Limits.filterQuery,
              // Лимит — в кодовых точках, как у `Limits` (решение 14А
              // plans/m4): `maxLength` считает графемы.
              inputFormatters: const [TextLimit(Limits.filterQuery)],
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                counterText: '',
              ),
              onChanged: _changed,
              onSubmitted: (_) => _activateSelected(),
            ),
          ),
          // И при одной вкладке: «Описания задач» без «Лучших совпадений»
          // объясняет, почему найдена задача без слова в названии.
          if (input is WordSearch && tabs.isNotEmpty)
            SearchTabs(
              tabs: tabs,
              selected: tab,
              onSelected: (t) => setState(() {
                _tab = t;
                _selected = 0;
              }),
            ),
          if (empty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.searchNothing,
                style: TextStyle(color: AppPalette.of(context).textSecondary),
              ),
            ),
          if (ws != null)
            Flexible(
              child: SearchList(
                // Новая строка, вкладка или выполненные — список сначала.
                key: ValueKey((_text.text, tab, _completed)),
                ws: ws,
                items: _items,
                selected: _selected,
                showKeys: widget.showKeys,
                onTap: _activate,
                onRemoveRecent: (text) => runCommand(
                  context,
                  () => ref.read(recentSearchCommandsProvider).remove(text),
                ),
                onClearRecent: () => runCommand(
                  context,
                  () => ref.read(recentSearchCommandsProvider).clear(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Задачи запроса фильтра — все его списки подряд, без повторов (в окне
  /// поиска — только задачи, допущение О-69).
  List<SearchHit> _filterHits(Workspace ws, FilterQuery query) {
    final seen = <String>{};
    final clock = ref.read(clockProvider);
    return [
      for (final list in evaluateFilter(
        ws,
        query,
        now: clock.nowWall(),
        wallOf: clock.wallOf,
      ))
        for (final task in list.tasks)
          if (seen.add(task.id)) TaskHit(task),
    ];
  }
}

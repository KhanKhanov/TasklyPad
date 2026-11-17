import 'package:flutter/services.dart';

// Команды оболочки — одна таблица для клавиш (ShellKeys) и окна «Поиск»
// (решение 3А plans/m5 «Решения M5.4»): переходы и действия, которые уже
// работают; клавиши — help «Use keyboard shortcuts», TODOIST_PARITY §10.
// Импорт flutter/services — только ради кодов клавиш.

/// Команда оболочки.
enum ShellCommandId {
  inbox,
  today,
  upcoming,
  projects,
  filtersLabels,
  settings,
  theme,
  addTask,
  addProject,
  addLabel,
  addFilter,
  sync,
  toggleSidebar,
  search,
}

/// Сочетание клавиш: [prefix], затем [key] (`g` `i`); [key] с
/// модификаторами; или набранный символ [character] (`/` — в русской
/// раскладке он набирается с Shift, клавиша у него другая).
final class ShellChord {
  /// Две клавиши по очереди.
  const ShellChord.sequence(LogicalKeyboardKey this.prefix, this.key)
    : ctrl = false,
      shift = false,
      alt = false,
      character = null;

  /// Клавиша; без модификаторов — только когда не печатают в поле.
  const ShellChord.key(
    this.key, {
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  }) : prefix = null,
       character = null;

  /// Набранный символ без Ctrl и Alt.
  const ShellChord.character(String this.character)
    : prefix = null,
      key = null,
      ctrl = false,
      shift = false,
      alt = false;

  final LogicalKeyboardKey? prefix;
  final LogicalKeyboardKey? key;
  final String? character;
  final bool ctrl;
  final bool shift;
  final bool alt;
}

/// Команда: [path] — у перехода; [chords] — её клавиши; [inPalette] — видна
/// в окне «Поиск» (сам поиск там не нужен).
final class ShellCommand {
  const ShellCommand(
    this.id, {
    this.path,
    this.chords = const [],
    this.inPalette = true,
  });

  final ShellCommandId id;
  final String? path;
  final List<ShellChord> chords;
  final bool inPalette;
}

const LogicalKeyboardKey _g = LogicalKeyboardKey.keyG;
const LogicalKeyboardKey _o = LogicalKeyboardKey.keyO;

/// Все команды в порядке окна «Поиск». `Ctrl+1…5` и `Ctrl+Shift+F` — в help
/// строки «mobile keyboard», у нас на всех платформах (решение 2А «Ход
/// M4.13», план M5 «Поиск и `Ctrl+K`»); `Ctrl+F` и `Ctrl+K` — «Open Search» и
/// «Open Quick Find» — одно окно (решение 2А «Решения M5.4»). «Новый проект» —
/// `Alt+P` и `Ctrl+Shift+P`, «Новая метка» — `Ctrl+Shift+L` (help; О-97,
/// решение 6А).
const List<ShellCommand> shellCommands = [
  ShellCommand(
    ShellCommandId.inbox,
    path: '/',
    chords: [
      ShellChord.sequence(_g, LogicalKeyboardKey.keyI),
      ShellChord.key(LogicalKeyboardKey.digit1, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.today,
    path: '/today',
    chords: [
      ShellChord.sequence(_g, LogicalKeyboardKey.keyT),
      ShellChord.key(LogicalKeyboardKey.digit2, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.upcoming,
    path: '/upcoming',
    chords: [
      ShellChord.sequence(_g, LogicalKeyboardKey.keyU),
      ShellChord.key(LogicalKeyboardKey.digit3, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.projects,
    path: '/projects',
    chords: [
      ShellChord.sequence(_g, LogicalKeyboardKey.keyP),
      ShellChord.key(LogicalKeyboardKey.digit4, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.filtersLabels,
    path: '/filters-labels',
    chords: [
      ShellChord.sequence(_g, LogicalKeyboardKey.keyV),
      ShellChord.sequence(_g, LogicalKeyboardKey.keyL),
      ShellChord.key(LogicalKeyboardKey.digit5, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.settings,
    path: '/settings',
    chords: [ShellChord.sequence(_o, LogicalKeyboardKey.keyS)],
  ),
  // «Настройки», открытые на «Теме».
  ShellCommand(
    ShellCommandId.theme,
    path: '/settings?section=theme',
    chords: [ShellChord.sequence(_o, LogicalKeyboardKey.keyT)],
  ),
  ShellCommand(
    ShellCommandId.addTask,
    chords: [
      ShellChord.key(LogicalKeyboardKey.keyQ),
      ShellChord.key(LogicalKeyboardKey.keyN, ctrl: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.addProject,
    chords: [
      ShellChord.key(LogicalKeyboardKey.keyP, alt: true),
      ShellChord.key(LogicalKeyboardKey.keyP, ctrl: true, shift: true),
    ],
  ),
  ShellCommand(
    ShellCommandId.addLabel,
    chords: [ShellChord.key(LogicalKeyboardKey.keyL, ctrl: true, shift: true)],
  ),
  ShellCommand(
    ShellCommandId.addFilter,
    chords: [ShellChord.key(LogicalKeyboardKey.keyF, ctrl: true, shift: true)],
  ),
  ShellCommand(
    ShellCommandId.sync,
    chords: [ShellChord.key(LogicalKeyboardKey.keyS, ctrl: true)],
  ),
  ShellCommand(
    ShellCommandId.toggleSidebar,
    chords: [ShellChord.key(LogicalKeyboardKey.keyM)],
  ),
  ShellCommand(
    ShellCommandId.search,
    inPalette: false,
    chords: [
      ShellChord.character('/'),
      ShellChord.key(LogicalKeyboardKey.keyF),
      ShellChord.key(LogicalKeyboardKey.keyF, ctrl: true),
      ShellChord.key(LogicalKeyboardKey.keyK, ctrl: true),
    ],
  ),
];

/// Клавиши, после которых ждётся вторая (`g`, `o`).
final Set<LogicalKeyboardKey> shellPrefixes = {
  for (final c in shellCommands)
    for (final chord in c.chords) ?chord.prefix,
};

/// Команда по сочетанию: [prefix] — нажатая перед этим `g` или `o`; [key]
/// с [ctrl], [shift] и [alt]; [character] — набранный символ. `null` — не
/// команда.
ShellCommand? shellCommandFor({
  LogicalKeyboardKey? prefix,
  required LogicalKeyboardKey key,
  String? character,
  bool ctrl = false,
  bool shift = false,
  bool alt = false,
}) {
  for (final command in shellCommands) {
    for (final chord in command.chords) {
      final match = switch (chord) {
        ShellChord(character: final c?) =>
          prefix == null && !ctrl && !alt && c == character,
        ShellChord(prefix: final p?) => p == prefix && chord.key == key,
        _ =>
          prefix == null &&
              chord.key == key &&
              chord.ctrl == ctrl &&
              chord.shift == shift &&
              chord.alt == alt,
      };
      if (match) return command;
    }
  }
  return null;
}

/// Команда [id] из таблицы.
ShellCommand shellCommand(ShellCommandId id) =>
    shellCommands.firstWhere((c) => c.id == id);

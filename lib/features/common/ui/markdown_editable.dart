import 'package:flutter/material.dart';

/// Поле с markdown по решению 7А плана M4: пока поле в работе — исходный
/// текст со знаками разметки ([editor]), вне работы — отрисованный
/// ([rendered]). Нажатие на отрисованный текст открывает поле с курсором,
/// нажатие на ссылку в нём — ссылку. Текст без разметки остаётся полем: он
/// выглядит так же, а поле сразу принимает курсор.
class MarkdownEditable extends StatefulWidget {
  const MarkdownEditable({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasMarkup,
    required this.decoration,
    required this.rendered,
    required this.editor,
    this.readOnly = false,
    this.onHold,
  });

  /// Текст поля [editor]: отрисованный вид берёт текст отсюда, а не из
  /// базы, — после ухода из поля он сразу показывает набранное.
  final TextEditingController controller;

  /// Фокус поля [editor].
  final FocusNode focusNode;

  /// В тексте есть разметка — есть что отрисовывать.
  final bool Function(String text) hasMarkup;

  /// Оформление поля: отрисованный текст стоит в тех же отступах.
  final InputDecoration decoration;
  final Widget Function(String text) rendered;
  final Widget editor;

  /// Только просмотр: ссылки работают, поле не открывается.
  final bool readOnly;

  /// Поле удерживается окном поверх ([hold]) — `true`, отпущено — `false`.
  /// Фокус в это время у окна, но поле в работе: окно задачи не сохраняет
  /// его по уходу фокуса и не подставляет в него значение из базы — иначе
  /// «Ссылка» в названии с датой записала бы срок раньше времени, а
  /// подставленный текст разошёлся бы с выделением (ревью M4.12).
  final ValueChanged<bool>? onHold;

  @override
  State<MarkdownEditable> createState() => _MarkdownEditableState();

  /// Выполнить [action] (окно поверх поля — «Ссылка» панели форматирования),
  /// не закрывая поле: без фокуса поле с разметкой показало бы отрисованный
  /// текст, и вернуть ему фокус и выделение после окна было бы нечем. Вне
  /// [MarkdownEditable] — просто [action].
  static Future<T> hold<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    final state = context.findAncestorStateOfType<_MarkdownEditableState>();
    state?._hold(1);
    try {
      return await action();
    } finally {
      state?._hold(-1);
    }
  }
}

class _MarkdownEditableState extends State<MarkdownEditable> {
  /// Поле открыто нажатием и ждёт фокуса.
  bool _opening = false;

  /// Сколько окон держат поле открытым ([MarkdownEditable.hold]).
  int _held = 0;

  void _hold(int delta) {
    if (!mounted) return;
    final was = _held > 0;
    setState(() => _held += delta);
    if (was != _held > 0) widget.onHold?.call(_held > 0);
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(MarkdownEditable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() {
      if (widget.focusNode.hasFocus) _opening = false;
    });
  }

  void _open() {
    setState(() => _opening = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode.requestFocus();
      // Фокус не пришёл (окно закрывается, фокус забрал диалог) — поле не
      // остаётся открытым навсегда.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _opening && !widget.focusNode.hasFocus) {
          setState(() => _opening = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.focusNode.hasFocus || _opening || _held > 0;
    final text = widget.controller.text;
    if (editing || !widget.hasMarkup(text)) return widget.editor;
    final view = InputDecorator(
      decoration: widget.decoration,
      child: widget.rendered(text),
    );
    if (widget.readOnly) return view;
    // Свой фокус у отрисованного вида: `Tab` по окну доходит до поля и
    // открывает его (help «Use keyboard shortcuts»: Tab — по элементам
    // панели), хотя поля ввода в дереве пока нет.
    return Focus(
      onFocusChange: (focused) {
        if (focused) _open();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: view,
        ),
      ),
    );
  }
}

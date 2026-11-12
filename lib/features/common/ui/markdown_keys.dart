import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../domain/rules.dart';
import '../logic/markdown_edits.dart';
import 'link_dialog.dart';
import 'markdown_editable.dart';
import 'markdown_toolbar.dart';

/// Форматирование поля с markdown: `Ctrl+B` — жирный (`**`), `Ctrl+I` —
/// курсив (`*`) — оборачивают выделение или снимают разметку (в help клавиш
/// нет — допущение, решение 7А плана M4, О-69); на компьютере при выделении —
/// панель [MarkdownToolbar] (help «Format text in a Todoist task»; решение 1А
/// «Ход M4.12»), на Android её нет, как в Todoist. Панели нужен [focusNode]
/// поля. Сверх лимита [max] текст не меняется; без [max] (строка быстрого
/// добавления с токенами — её лимит проверяет команда) — без проверки.
class MarkdownKeys extends StatefulWidget {
  const MarkdownKeys({
    super.key,
    required this.controller,
    required this.child,
    this.focusNode,
    this.max,
    this.enabled = true,
    this.blocks = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int? max;
  final bool enabled;

  /// Поле описания: в панели есть «Цитата».
  final bool blocks;
  final Widget child;

  @override
  State<MarkdownKeys> createState() => _MarkdownKeysState();
}

class _MarkdownKeysState extends State<MarkdownKeys> {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _field = GlobalKey();

  /// Открыто окно «Ссылка»: панель спрятана.
  bool _linking = false;

  /// Место над выделением в координатах поля — после раскладки поля: при
  /// сборке у поля ещё старый текст (ревью M4.12).
  final ValueNotifier<Offset> _offset = ValueNotifier(const Offset(0, -4));

  /// Ширина панели с запасом — чтобы не уйти за правый край окна.
  static const double _toolbarWidth = 260;

  static bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocus);
    widget.controller.addListener(_measureLater);
  }

  @override
  void didUpdateWidget(MarkdownKeys oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocus);
      widget.focusNode?.addListener(_onFocus);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_measureLater);
      widget.controller.addListener(_measureLater);
    }
    if (oldWidget.enabled != widget.enabled) _onFocus();
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocus);
    widget.controller.removeListener(_measureLater);
    _offset.dispose();
    super.dispose();
  }

  /// Панель живёт, пока поле в фокусе; видна — при выделении. Структура
  /// дерева от [MarkdownKeys.enabled] не зависит: иначе поле пересоздавалось
  /// бы и теряло фокус, когда проект уходит в архив на другом устройстве.
  void _onFocus() {
    if (!mounted) return;
    final show =
        widget.enabled && _desktop && (widget.focusNode?.hasFocus ?? false);
    if (show) {
      _portal.show();
      _measureLater();
    } else if (_portal.isShowing) {
      _portal.hide();
    }
  }

  void _measureLater() {
    if (!_portal.isShowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offset.value = _anchor();
    });
  }

  /// Применить [change]: каждая замена — отдельная правка «набор вместо
  /// выделения». По ней контроллер поля понимает, где менялся текст, и
  /// отменённые пользователем даты и токены едут вместе с текстом; одной
  /// правкой с выделением на выходе он искал бы место по общему началу и
  /// концу строк и терял их — снятие жирного с «**Позвонить в пятницу**»
  /// поставило бы срок (ревью M4.12).
  void _apply(MarkdownChange? change) {
    if (change == null) return;
    final controller = widget.controller;
    final after = change.apply(controller.value).text;
    final max = widget.max;
    if (max != null &&
        Limits.length(after) > max &&
        Limits.length(after) > Limits.length(controller.text)) {
      return;
    }
    for (final edit in change.edits) {
      controller.selection = TextSelection(
        baseOffset: edit.at,
        extentOffset: edit.at + edit.remove,
      );
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(
          edit.at,
          edit.at + edit.remove,
          edit.insert,
        ),
        selection: TextSelection.collapsed(
          offset: edit.at + edit.insert.length,
        ),
      );
    }
    controller.selection = change.selection;
  }

  void _format(MarkdownFormat format) => switch (format) {
    MarkdownFormat.bold => _apply(markerToggle(widget.controller.value, '**')),
    MarkdownFormat.italic => _apply(markerToggle(widget.controller.value, '*')),
    MarkdownFormat.strikethrough => _apply(
      markerToggle(widget.controller.value, '~~'),
    ),
    MarkdownFormat.code => _apply(markerToggle(widget.controller.value, '`')),
    MarkdownFormat.quote => _apply(quoteToggle(widget.controller.value)),
    MarkdownFormat.link => _editLink(),
  };

  /// «Ссылка»: окно с адресом; у существующей ссылки — её адрес и корзина.
  /// Пока окно открыто, поле остаётся полем ([MarkdownEditable.hold]), а
  /// после — получает фокус и прежнее выделение назад.
  Future<void> _editLink() async {
    final before = widget.controller.value;
    final existing = linkAt(before.text, before.selection);
    setState(() => _linking = true);
    final pick = await MarkdownEditable.hold(
      context,
      () => showLinkDialog(
        context,
        url: existing?.url ?? '',
        canRemove: existing != null,
      ),
    );
    if (!mounted) return;
    setState(() => _linking = false);
    widget.focusNode?.requestFocus();
    // Текст сменился, пока окно было открыто (правка с другого устройства) —
    // выделение уже не то.
    if (pick == null || widget.controller.text != before.text) return;
    widget.controller.selection = before.selection;
    // `null` у новой ссылки — выделение задевает другую ссылку или содержит
    // `[`, `]`, перевод строки: ссылка не ставится.
    _apply(switch (pick) {
      LinkSet(:final url) => linkChange(before, url),
      LinkRemove() => existing == null ? null : unlinkChange(existing),
    });
  }

  /// Где над полем начинается выделение: левый край его первой строки.
  Offset _anchor() {
    final box = _field.currentContext?.findRenderObject();
    final editable = box == null ? null : _editableIn(box);
    final selection = widget.controller.selection;
    if (box is! RenderBox ||
        editable == null ||
        !editable.hasSize ||
        !selection.isValid ||
        selection.end > widget.controller.text.length) {
      return const Offset(0, -4);
    }
    final point = editable.getEndpointsForSelection(selection).first.point;
    final local = MatrixUtils.transformPoint(
      editable.getTransformTo(box),
      point,
    );
    return Offset(local.dx, local.dy - editable.preferredLineHeight - 4);
  }

  static RenderEditable? _editableIn(RenderObject node) {
    if (node is RenderEditable) return node;
    RenderEditable? found;
    node.visitChildren((child) => found ??= _editableIn(child));
    return found;
  }

  /// Панель в слое поверх окна: [info] — где поле в окне, его Flutter
  /// передаёт во время раскладки. Не `CompositedTransformFollower`: место
  /// такого виджета известно только после раскладки, и подсказка кнопки
  /// (`Tooltip`, тоже в слое поверх) при наведении мыши падала с ошибкой
  /// «paint transform cannot be reliably computed» (ручная проверка M4.12).
  Widget _toolbar(BuildContext context, OverlayChildLayoutInfo info) =>
      ListenableBuilder(
        listenable: Listenable.merge([widget.controller, _offset]),
        builder: (context, _) {
          final selection = widget.controller.selection;
          if (_linking || !selection.isValid || selection.isCollapsed) {
            return const SizedBox.shrink();
          }
          final at = MatrixUtils.transformPoint(
            info.childPaintTransform,
            _offset.value,
          );
          final overlay = info.overlaySize;
          // Выделение ушло из окна (прокрутка) — панели нет.
          if (at.dy < 0 || at.dy > overlay.height) {
            return const SizedBox.shrink();
          }
          // Не за край окна: слева — отступ, справа — место для панели.
          final left = at.dx
              .clamp(8.0, max(8.0, overlay.width - _toolbarWidth))
              .toDouble();
          return Stack(
            children: [
              Positioned(
                left: left,
                bottom: overlay.height - at.dy,
                child: MarkdownToolbar(
                  blocks: widget.blocks,
                  onPressed: _format,
                ),
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (widget.enabled) ...{
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
              _format(MarkdownFormat.bold),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
              _format(MarkdownFormat.italic),
        },
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: _toolbar,
        child: KeyedSubtree(key: _field, child: widget.child),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Итог окна «Ссылка»: новый адрес или «убрать ссылку».
sealed class LinkPick {
  const LinkPick();
}

/// Сделать выделение ссылкой на [url] (или сменить адрес).
final class LinkSet extends LinkPick {
  const LinkSet(this.url);
  final String url;
}

/// Убрать ссылку, оставив текст (help: «Link» → значок корзины).
final class LinkRemove extends LinkPick {
  const LinkRemove();
}

/// Окно «Ссылка» панели форматирования: адрес [url] (у существующей ссылки —
/// её адрес) и корзина, если ссылка уже есть ([canRemove]). `null` — закрыли
/// или адрес пустой.
Future<LinkPick?> showLinkDialog(
  BuildContext context, {
  String url = '',
  bool canRemove = false,
}) => showDialog<LinkPick>(
  context: context,
  builder: (context) => _LinkDialog(url: url, canRemove: canRemove),
);

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.url, required this.canRemove});

  final String url;
  final bool canRemove;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _url = TextEditingController(
    text: widget.url,
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final url = _url.text.trim();
    // Пробел и скобки в адресе разорвали бы разметку `[текст](адрес)`.
    final safe = url
        .replaceAll(RegExp(r'\s'), '%20')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29');
    Navigator.pop(context, url.isEmpty ? null : LinkSet(safe));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.formatLink)),
          if (widget.canRemove)
            IconButton(
              tooltip: l10n.removeLink,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => Navigator.pop(context, const LinkRemove()),
            ),
        ],
      ),
      content: TextField(
        controller: _url,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(labelText: l10n.linkAddress),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}

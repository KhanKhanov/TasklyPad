import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Экран «Входящие» — проект по умолчанию. Пока пустой: список задач в M2.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inbox)),
      body: Center(child: Text(l10n.inboxEmpty)),
    );
  }
}

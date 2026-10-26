import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// «Перенести в…»: «Входящие» и проекты с разделами.
Future<({String projectId, String? sectionId})?> pickPlace(
  BuildContext context,
  Workspace ws,
) {
  final l10n = AppLocalizations.of(context);
  final inbox = ws.inbox;
  Iterable<Widget> sectionsOf(BuildContext context, String id, int depth) => [
    for (final s in ws.sectionsOf(id))
      SimpleDialogOption(
        onPressed: () =>
            Navigator.pop(context, (projectId: id, sectionId: s.id)),
        child: Padding(
          padding: EdgeInsets.only(left: depth * 16.0 + 28),
          child: Text(s.name, overflow: TextOverflow.ellipsis),
        ),
      ),
  ];
  return showDialog<({String projectId, String? sectionId})>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.actionMoveTo),
      children: [
        if (inbox != null) ...[
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, (projectId: inbox.id, sectionId: null)),
            child: Text(l10n.inbox),
          ),
          ...sectionsOf(context, inbox.id, 0),
        ],
        for (final item in ws.projectTree(expandCollapsed: true)) ...[
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (
              projectId: item.value.id,
              sectionId: null,
            )),
            child: Row(
              children: [
                SizedBox(width: item.depth * 16.0),
                ProjectHash(color: item.value.color, size: 15),
                Flexible(
                  child: Text(item.value.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          ...sectionsOf(context, item.value.id, item.depth),
        ],
      ],
    ),
  );
}

/// Выбор меток: отметить существующие или создать новую по введённому имени.
Future<Set<String>?> pickLabels(
  BuildContext context,
  Workspace ws,
  List<String> current,
) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _LabelPicker(ws: ws, initial: current.toSet()),
);

class _LabelPicker extends ConsumerStatefulWidget {
  const _LabelPicker({required this.ws, required this.initial});

  final Workspace ws;
  final Set<String> initial;

  @override
  ConsumerState<_LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends ConsumerState<_LabelPicker> {
  late final Set<String> _selected = {...widget.initial};
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _busy = false;

  /// Повторное нажатие, пока метка пишется, создало бы вторую такую же.
  Future<void> _create() async {
    if (_busy) return;
    final name = _query.text.trim();
    setState(() => _busy = true);
    await runCommand(context, () async {
      final id = await ref.read(labelCommandsProvider).add(name: name);
      if (!mounted) return;
      _selected.add(id);
      _query.clear();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels =
        ref.watch(workspaceProvider).value?.labels ?? widget.ws.labels;
    final q = _query.text.trim().toLowerCase();
    final shown = [
      for (final l in labels)
        if (q.isEmpty || l.name.toLowerCase().contains(q)) l,
    ];
    final exact = labels.any((l) => l.name.toLowerCase() == q);
    return AlertDialog(
      title: Text(l10n.fieldLabels),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.labelSearchHint),
              onChanged: (_) => setState(() {}),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in shown)
                    CheckboxListTile(
                      value: _selected.contains(l.id),
                      title: Text(l.name),
                      secondary: Icon(
                        Icons.sell_outlined,
                        color: projectColor(l.color),
                      ),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _selected.add(l.id)
                            : _selected.remove(l.id),
                      ),
                    ),
                  if (q.isNotEmpty && !exact)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l10n.createLabel(_query.text.trim())),
                      onTap: _create,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _selected),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }
}

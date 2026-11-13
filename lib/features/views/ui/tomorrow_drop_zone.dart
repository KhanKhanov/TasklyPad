import 'package:flutter/material.dart';

import '../../common/ui/drag_rows.dart';
import '../../tasks/ui/task_drop_calc.dart';

/// Зона «на завтра» в «Сегодня» (решение 2А «Ход M4.9»): пустое место под
/// списком. Брошенная сюда задача получает срок [date] — завтра; пока над
/// зоной указатель, сверху видны линия и подпись [label] («Завтра»).
class TomorrowDropZone extends StatelessWidget {
  const TomorrowDropZone({super.key, required this.date, required this.label});

  /// Завтрашний день, `YYYY-MM-DD`.
  final String date;
  final String label;

  @override
  Widget build(BuildContext context) => DropArea(
    owner: 'tomorrow',
    resolve: (query, _) =>
        tomorrowPlace(query.payload, date, owner: 'tomorrow', label: label),
    child: const SizedBox(width: double.infinity, height: 72),
  );
}

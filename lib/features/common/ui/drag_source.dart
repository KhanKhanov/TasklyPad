import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../state/drag_session.dart';
import 'drag_layer.dart';

export 'drag_draggables.dart';

/// Ручка слева от строки: появляется при наведении, под ней — курсор «рука».
class DragGrip extends StatelessWidget {
  const DragGrip({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: AppLocalizations.of(context).dragHandleHint,
    child: MouseRegion(
      cursor: SystemMouseCursors.grab,
      // Прозрачный цвет нужен, чтобы пустое место ручки ловило указатель.
      child: ColoredBox(
        color: Colors.transparent,
        child: Center(
          child: Icon(
            Icons.drag_indicator,
            size: 18,
            color: AppPalette.of(context).textSecondary,
          ),
        ),
      ),
    ),
  );
}

/// Образ под указателем: название и, если тащат несколько задач, их число.
class DragGhost extends StatelessWidget {
  const DragGhost({super.key, required this.title, required this.payload});

  final String title;
  final DragPayload payload;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final count = payload.sources.length;
    return Material(
      color: palette.raised,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
              if (count > 1) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: palette.accent,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка перетаскиваемого элемента бледнеет, пока его тащат.
class DragSourceDim extends ConsumerWidget {
  const DragSourceDim({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragged = ref.watch(
      dragSessionProvider.select((s) => s?.sources.contains(id) ?? false),
    );
    // Корень один и тот же всегда: смена типа пересоздала бы поддерево строки
    // и унесла фокус и несохранённую правку.
    return Opacity(opacity: dragged ? 0.4 : 1, child: child);
  }
}

/// Пока идёт перетаскивание, [child] не получает указатель: у строк под ним
/// не появляются ручка, подсказка и «⋯». Слот броска стоит снаружи и
/// продолжает ловить попадание.
class DragBlocker extends ConsumerWidget {
  const DragBlocker({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragging = ref.watch(dragSessionProvider.select((s) => s != null));
    return IgnorePointer(ignoring: dragging, child: child);
  }
}

/// Рисует место броска поверх [child], если оно принадлежит [owner]: линию
/// сверху или снизу либо рамку. Раскладка не меняется — линия лежит поверх.
class DropMarker extends ConsumerWidget {
  const DropMarker({super.key, required this.owner, required this.child});

  final Object owner;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mark = ref.watch(
      dragSessionProvider.select(
        (s) => s?.indicator?.owner == owner ? s!.indicator : null,
      ),
    );
    return CustomPaint(
      foregroundPainter: mark == null
          ? null
          : _MarkPainter(mark, AppPalette.of(context).accent),
      child: child,
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark, this.color);

  final DropIndicator mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    switch (mark.mark) {
      case DropMark.frame:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(1),
            const Radius.circular(6),
          ),
          paint,
        );
      case DropMark.above || DropMark.below:
        final y = mark.mark == DropMark.above ? 1.0 : size.height - 1;
        canvas.drawLine(Offset(mark.indent, y), Offset(size.width, y), paint);
        canvas.drawCircle(
          Offset(mark.indent, y),
          4,
          paint..style = PaintingStyle.fill,
        );
        final caption = mark.caption;
        if (caption != null) {
          // Подпись у правого края под линией (над ней — у нижней линии).
          final text = TextPainter(
            text: TextSpan(
              text: caption,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(
            canvas,
            Offset(
              size.width - text.width - 8,
              mark.mark == DropMark.above ? y + 3 : y - text.height - 3,
            ),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}

import 'package:flutter/material.dart';

/// Эффект «джин», как сворачивание окна в Dock на macOS (решение
/// пользователя 1А — наше дополнение, в Todoist тост просто проявляется):
/// [child] втягивается воронкой в точку под собой и вытекает обратно.
/// [progress] 1 — на месте, 0 — втянут. Пока идёт анимация, [child]
/// рисуется [strips] горизонтальными полосками, каждая сжата по ширине и
/// сдвинута вниз по-своему — так края изгибаются воронкой (обычный
/// `Transform` гнёт только весь прямоугольник сразу). Нажатий во время
/// анимации нет.
class GenieTransition extends StatelessWidget {
  const GenieTransition({
    super.key,
    required this.progress,
    required this.child,
    this.strips = 48,
    this.depth = 16,
  });

  final Animation<double> progress;
  final Widget child;
  final int strips;

  /// Насколько ниже нижнего края [child] точка, куда он втягивается: у тоста
  /// — нижний край окна, как Dock в macOS (отступ тоста снизу — около 16).
  final double depth;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) {
      final t = progress.value;
      if (t >= 1) return child!;
      return IgnorePointer(
        child: _GenieStrips(
          collapse: 1 - t,
          strips: strips,
          depth: depth,
          child: child!,
        ),
      );
    },
  );
}

class _GenieStrips extends StatelessWidget {
  const _GenieStrips({
    required this.collapse,
    required this.strips,
    required this.depth,
    required this.child,
  });

  final double collapse;
  final int strips;
  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // Место и размер — как у видимого тоста; сам он не рисуется.
      Opacity(opacity: 0, child: child),
      for (var i = 0; i < strips; i++)
        Positioned.fill(
          child: _GenieStrip(
            index: i,
            strips: strips,
            collapse: collapse,
            depth: depth,
            child: child,
          ),
        ),
    ],
  );
}

class _GenieStrip extends StatelessWidget {
  const _GenieStrip({
    required this.index,
    required this.strips,
    required this.collapse,
    required this.depth,
    required this.child,
  });

  final int index;
  final int strips;
  final double collapse;
  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      final band = h / strips;
      final top = index * band;
      final mid = top + band / 2;
      final target = h + depth;
      // Первая половина — края изгибаются воронкой, вторая — содержимое
      // съезжает в неё.
      final bend = (collapse * 2).clamp(0.0, 1.0);
      final slide = ((collapse - 0.5) * 2).clamp(0.0, 1.0) * target;
      final y = mid + slide;
      if (y >= target) return const SizedBox.shrink();
      final funnel = Curves.easeInOut.transform((y / target).clamp(0, 1));
      final width = w * (1 - bend * funnel * 0.94);
      final scale = width / w;
      final matrix = Matrix4.identity()
        ..translateByDouble(w / 2, slide, 0, 1)
        ..scaleByDouble(scale, 1, 1, 1)
        ..translateByDouble(-w / 2, 0, 0, 1);
      return Transform(
        transform: matrix,
        child: ClipRect(clipper: _Band(top, band + 0.6), child: child),
      );
    },
  );
}

class _Band extends CustomClipper<Rect> {
  const _Band(this.top, this.height);

  final double top;
  final double height;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, top, size.width, height);

  @override
  bool shouldReclip(_Band old) => old.top != top || old.height != height;
}

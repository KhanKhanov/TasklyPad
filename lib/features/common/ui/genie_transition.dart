import 'package:flutter/material.dart';

/// Эффект «джин», как сворачивание окна в Dock на macOS (решение
/// пользователя 1А — наше дополнение, в Todoist тост просто проявляется):
/// [child] втягивается воронкой в «лампу» [target] и вытекает из неё.
/// [progress] 1 — на месте, 0 — втянут. Пока идёт анимация, [child]
/// рисуется [strips] горизонтальными полосками, каждая сжата по ширине,
/// сдвинута вниз и к лампе по-своему ([genieBand]) — так края изгибаются
/// S-кривой, как у привидения, втекающего в лампу (обычный `Transform` гнёт
/// только весь прямоугольник сразу). Нажатий во время анимации нет.
class GenieTransition extends StatelessWidget {
  const GenieTransition({
    super.key,
    required this.progress,
    required this.child,
    this.strips = 48,
    this.depth = 16,
    this.target,
    this.mouthWidth,
  });

  final Animation<double> progress;
  final Widget child;
  final int strips;

  /// Насколько ниже нижнего края [child] лампа как минимум; без [target] —
  /// точка под серединой на этой глубине (отступ тоста снизу — около 16).
  final double depth;

  /// Горлышко лампы в координатах [child] (решения 1А–5А plans/m5 «Решения
  /// M5.3a» — вкладка «Уведомления»); `null` — под серединой на [depth].
  /// Лампа выше, чем [depth] под нижним краем [child], опускается туда.
  final Offset? target;

  /// Ширина горлышка; `null` — 6% ширины [child].
  final double? mouthWidth;

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
          target: target,
          mouthWidth: mouthWidth,
          child: child!,
        ),
      );
    },
  );
}

/// Полоска «джина» при сворачивании: центр по горизонтали, сжатие по
/// ширине, сдвиг вниз и видна ли она ещё (за горлышком — нет).
typedef GenieBand = ({
  double centerX,
  double scaleX,
  double slide,
  bool visible,
});

/// Где полоска с серединой [bandMid] (в покое) при сворачивании [collapse]
/// (0 — на месте, 1 — в лампе) у [child] шириной [width]; лампа [target] —
/// в координатах [child], ниже его нижнего края. Две фазы, как у macOS:
/// первая половина — края изгибаются, вторая — содержимое съезжает в
/// горлышко. Изгиб — по smoothstep σ(s) = s²(3 − 2s) от доли пути до лампы:
/// у тоста и у горлышка края вертикальны, между ними — S-кривая; центр
/// полоски уходит от середины к X лампы, ширина — к [mouthWidth].
GenieBand genieBand({
  required double collapse,
  required double bandMid,
  required double width,
  required Offset target,
  required double mouthWidth,
}) {
  final lampY = target.dy;
  final bend = (collapse * 2).clamp(0.0, 1.0);
  final slide = ((collapse - 0.5) * 2).clamp(0.0, 1.0) * lampY;
  final y = bandMid + slide;
  final s = (y / lampY).clamp(0.0, 1.0);
  final sigma = s * s * (3 - 2 * s) * bend;
  final half = width / 2;
  return (
    centerX: half + (target.dx - half) * sigma,
    scaleX: (width + (mouthWidth - width) * sigma) / width,
    slide: slide,
    visible: y < lampY,
  );
}

class _GenieStrips extends StatelessWidget {
  const _GenieStrips({
    required this.collapse,
    required this.strips,
    required this.depth,
    required this.target,
    required this.mouthWidth,
    required this.child,
  });

  final double collapse;
  final int strips;
  final double depth;
  final Offset? target;
  final double? mouthWidth;
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
            target: target,
            mouthWidth: mouthWidth,
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
    required this.target,
    required this.mouthWidth,
    required this.child,
  });

  final int index;
  final int strips;
  final double collapse;
  final double depth;
  final Offset? target;
  final double? mouthWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      final band = h / strips;
      final top = index * band;
      final lamp = target ?? Offset(w / 2, h + depth);
      final g = genieBand(
        collapse: collapse,
        bandMid: top + band / 2,
        width: w,
        target: Offset(lamp.dx, lamp.dy < h + depth ? h + depth : lamp.dy),
        mouthWidth: mouthWidth ?? w * 0.06,
      );
      if (!g.visible) return const SizedBox.shrink();
      final matrix = Matrix4.identity()
        ..translateByDouble(g.centerX, g.slide, 0, 1)
        ..scaleByDouble(g.scaleX, 1, 1, 1)
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

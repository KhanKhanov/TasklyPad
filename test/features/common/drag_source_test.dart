import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_source.dart';

// Строительные блоки перетаскивания: исходная строка бледнеет, не
// пересоздаваясь (иначе строка теряет фокус и несохранённую правку).
void main() {
  testWidgets('DragSourceDim: поддерево живёт то же при начале и конце '
      'перетаскивания, прозрачность 0.4 только пока тащат', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var created = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DragSourceDim(
            id: 'a',
            child: _Probe(onCreate: () => created++),
          ),
        ),
      ),
    );
    expect(created, 1);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

    container.read(dragSessionProvider.notifier).update({'a'}, null);
    await tester.pump();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);

    container.read(dragSessionProvider.notifier).clear();
    await tester.pump();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(created, 1, reason: 'состояние строки не пересоздавалось');
  });

  testWidgets('DragBlocker: пока тащат, указатель до содержимого не '
      'доходит', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var taps = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DragBlocker(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);

    container.read(dragSessionProvider.notifier).update({'a'}, null);
    await tester.pump();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });
}

/// Виджет с состоянием: счётчик созданий.
class _Probe extends StatefulWidget {
  const _Probe({required this.onCreate});

  final VoidCallback onCreate;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

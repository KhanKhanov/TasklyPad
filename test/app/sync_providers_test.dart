import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/sync_providers.dart';

import '../sync/support/devices.dart';

void main() {
  test('без подстановки в main ядро данных недоступно — понятная ошибка', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(mutatorProvider), throwsA(anything));
  });

  test('база, движок и Mutator — из подставленного ядра данных', () async {
    final dev = await TestDevice.start();
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(dev.services)],
    );
    addTearDown(container.dispose);

    expect(container.read(appDatabaseProvider), same(dev.db));
    expect(container.read(mergeEngineProvider), same(dev.services.engine));
    expect(container.read(mutatorProvider), same(dev.services.mutator));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/result.dart';

void main() {
  test('Ok — isOk, valueOrNull, fold', () {
    const Result<int> r = Result.ok(42);
    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 42);
    expect(r.fold((v) => 'v=$v', (e) => 'e=$e'), 'v=42');
  });

  test('Err — isErr, valueOrNull null, fold', () {
    const Result<int> r = Result.err('boom');
    expect(r.isErr, isTrue);
    expect(r.valueOrNull, isNull);
    expect(r.fold((v) => 'v=$v', (e) => 'e=$e'), 'e=boom');
  });

  test('map — преобразует Ok и не трогает Err', () {
    expect(const Result<int>.ok(2).map((v) => v * 2).valueOrNull, 4);
    final err = const Result<int>.err('x').map((v) => v * 2);
    expect(err, isA<Err<int>>());
  });

  test('guard — исключение превращается в Err со стеком', () async {
    final r = await Result.guard<int>(() async => throw StateError('нет'));
    switch (r) {
      case Ok():
        fail('ожидался Err');
      case Err(:final error, :final stackTrace):
        expect(error, isA<StateError>());
        expect(stackTrace, isNotNull);
    }
  });

  test('switch по sealed-классу исчерпывающий', () {
    String describe(Result<int> r) => switch (r) {
      Ok(:final value) => 'ok $value',
      Err(:final error) => 'err $error',
    };
    expect(describe(const Ok(1)), 'ok 1');
    expect(describe(const Err('e')), 'err e');
  });
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_notices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ищет новые конфликты по таблице конфликтов, а не по отчёту прохода (О-9):
/// при запуске и после каждого прохода и смены папки — удачных или нет.
/// Не на каждое изменение таблицы: проход — несколько транзакций, и конфликт,
/// который разрешит следующий чанк того же прохода, дал бы ложное
/// уведомление. Каждое новое состояние — повод уведомить (оболочка).

@ProviderFor(ConflictNotices)
final conflictNoticesProvider = ConflictNoticesProvider._();

/// Ищет новые конфликты по таблице конфликтов, а не по отчёту прохода (О-9):
/// при запуске и после каждого прохода и смены папки — удачных или нет.
/// Не на каждое изменение таблицы: проход — несколько транзакций, и конфликт,
/// который разрешит следующий чанк того же прохода, дал бы ложное
/// уведомление. Каждое новое состояние — повод уведомить (оболочка).
final class ConflictNoticesProvider
    extends $NotifierProvider<ConflictNotices, ConflictNotice?> {
  /// Ищет новые конфликты по таблице конфликтов, а не по отчёту прохода (О-9):
  /// при запуске и после каждого прохода и смены папки — удачных или нет.
  /// Не на каждое изменение таблицы: проход — несколько транзакций, и конфликт,
  /// который разрешит следующий чанк того же прохода, дал бы ложное
  /// уведомление. Каждое новое состояние — повод уведомить (оболочка).
  ConflictNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conflictNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conflictNoticesHash();

  @$internal
  @override
  ConflictNotices create() => ConflictNotices();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConflictNotice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConflictNotice?>(value),
    );
  }
}

String _$conflictNoticesHash() => r'3b068f8fc26384ed25ee0c2d9cb9baf0e993a920';

/// Ищет новые конфликты по таблице конфликтов, а не по отчёту прохода (О-9):
/// при запуске и после каждого прохода и смены папки — удачных или нет.
/// Не на каждое изменение таблицы: проход — несколько транзакций, и конфликт,
/// который разрешит следующий чанк того же прохода, дал бы ложное
/// уведомление. Каждое новое состояние — повод уведомить (оболочка).

abstract class _$ConflictNotices extends $Notifier<ConflictNotice?> {
  ConflictNotice? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConflictNotice?, ConflictNotice?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConflictNotice?, ConflictNotice?>,
              ConflictNotice?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

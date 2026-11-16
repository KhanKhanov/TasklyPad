// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_index.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Свёрнутые тексты текущего снимка для окна «Поиск»; `null` — снимок ещё
/// грузится. Живёт, пока открыто окно (autoDispose): разбор markdown всех
/// задач не повторяется на каждую правку, когда окна нет.

@ProviderFor(searchIndex)
final searchIndexProvider = SearchIndexProvider._();

/// Свёрнутые тексты текущего снимка для окна «Поиск»; `null` — снимок ещё
/// грузится. Живёт, пока открыто окно (autoDispose): разбор markdown всех
/// задач не повторяется на каждую правку, когда окна нет.

final class SearchIndexProvider
    extends $FunctionalProvider<SearchIndex?, SearchIndex?, SearchIndex?>
    with $Provider<SearchIndex?> {
  /// Свёрнутые тексты текущего снимка для окна «Поиск»; `null` — снимок ещё
  /// грузится. Живёт, пока открыто окно (autoDispose): разбор markdown всех
  /// задач не повторяется на каждую правку, когда окна нет.
  SearchIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchIndexHash();

  @$internal
  @override
  $ProviderElement<SearchIndex?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SearchIndex? create(Ref ref) {
    return searchIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchIndex? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchIndex?>(value),
    );
  }
}

String _$searchIndexHash() => r'7cf8032a7796d0435711162e1ffc7ab836c12c27';

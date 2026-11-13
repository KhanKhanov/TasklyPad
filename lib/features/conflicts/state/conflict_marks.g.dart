// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_marks.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Пометки спорных сущностей; строки берут свой `bool` через `select`.

@ProviderFor(conflictMarks)
final conflictMarksProvider = ConflictMarksProvider._();

/// Пометки спорных сущностей; строки берут свой `bool` через `select`.

final class ConflictMarksProvider
    extends $FunctionalProvider<ConflictMarks, ConflictMarks, ConflictMarks>
    with $Provider<ConflictMarks> {
  /// Пометки спорных сущностей; строки берут свой `bool` через `select`.
  ConflictMarksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conflictMarksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conflictMarksHash();

  @$internal
  @override
  $ProviderElement<ConflictMarks> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConflictMarks create(Ref ref) {
    return conflictMarks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConflictMarks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConflictMarks>(value),
    );
  }
}

String _$conflictMarksHash() => r'bb0f24dfa5336cb05cb3b14d7922800c19669bf0';

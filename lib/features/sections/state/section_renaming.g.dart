// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section_renaming.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Разделы, имя которых сейчас правят на месте: пока поле открыто, раздел не
/// перетаскивается (долгое нажатие в поле — выделение текста, а не перенос).
/// Состояние интерфейса этого устройства, не синхронизируется.

@ProviderFor(SectionRenaming)
final sectionRenamingProvider = SectionRenamingProvider._();

/// Разделы, имя которых сейчас правят на месте: пока поле открыто, раздел не
/// перетаскивается (долгое нажатие в поле — выделение текста, а не перенос).
/// Состояние интерфейса этого устройства, не синхронизируется.
final class SectionRenamingProvider
    extends $NotifierProvider<SectionRenaming, Set<String>> {
  /// Разделы, имя которых сейчас правят на месте: пока поле открыто, раздел не
  /// перетаскивается (долгое нажатие в поле — выделение текста, а не перенос).
  /// Состояние интерфейса этого устройства, не синхронизируется.
  SectionRenamingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sectionRenamingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sectionRenamingHash();

  @$internal
  @override
  SectionRenaming create() => SectionRenaming();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$sectionRenamingHash() => r'6f77ea33a00b6439d01e1399e4e518f5c4cba29d';

/// Разделы, имя которых сейчас правят на месте: пока поле открыто, раздел не
/// перетаскивается (долгое нажатие в поле — выделение текста, а не перенос).
/// Состояние интерфейса этого устройства, не синхронизируется.

abstract class _$SectionRenaming extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

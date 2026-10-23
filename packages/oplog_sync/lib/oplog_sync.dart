/// Ядро синхронизации без сервера: op-log CRDT, LWW по полям, HLC.
///
/// Пакет не зависит от Flutter и файловой системы — см. README.md.
library;

export 'src/conflict.dart';
export 'src/folder_transport.dart';
export 'src/fs.dart';
export 'src/hlc.dart';
export 'src/merge_engine.dart';
export 'src/op.dart';
export 'src/sync_state.dart';

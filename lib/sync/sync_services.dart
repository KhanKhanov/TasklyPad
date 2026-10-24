import 'package:oplog_sync/oplog_sync.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../data/app_database.dart';
import '../data/local_meta_dao.dart';
import '../data/projection/entity_fields.dart';
import '../data/projection/projector.dart';
import 'drift_op_store.dart';
import 'drift_sync_state_store.dart';
import 'folder_sync.dart';
import 'mutator.dart';
import 'node_identity.dart';
import 'sync_lease.dart';

/// Папка синхронизации внутри выбранной пользователем общей папки.
const String syncFolderName = 'planner-sync';

/// Собранное ядро данных одного запуска: база, движок и [Mutator].
///
/// На одну базу — один экземпляр (провайдер `syncServicesProvider`): второй
/// движок вёл бы свои часы, и метки HLC одного узла могли бы совпасть.
final class SyncServices {
  SyncServices._({
    required this.db,
    required this.store,
    required this.meta,
    required this.engine,
    required this.mutator,
    required this.identity,
    required this._clock,
    required this._ids,
  });

  final AppDatabase db;
  final DriftOpStore store;
  final LocalMetaDao meta;
  final MergeEngine engine;
  final Mutator mutator;
  final NodeIdentity identity;
  final AppClock _clock;
  final IdGenerator _ids;

  String get nodeId => engine.nodeId;

  /// Синхронизация с общей папкой [fs] (корень — выбранная пользователем
  /// папка, внутри неё [syncFolderName]). У каждого экземпляра своя аренда,
  /// поэтому два экземпляра не синхронизируют одновременно.
  FolderSync folderSync(
    SyncFs fs, {
    Map<String, Object?> deviceInfo = const {},
  }) => FolderSync(
    transport: FolderTransport(
      fs: fs,
      engine: engine,
      state: DriftSyncStateStore(db),
      root: syncFolderName,
      deviceInfo: deviceInfo,
    ),
    lease: SyncLease(db, owner: _ids.next(), clock: _clock),
    meta: meta,
  );

  Future<void> close() => db.close();
}

/// Запустить ядро данных над открытой базой [db].
///
/// Порядок: переложить таблицы, если обновился реестр проекторов → опознать
/// узел (новая база, та же или копия) → восстановить часы → движок и
/// [Mutator] → для копии записать заново невыгруженные правки прежнего узла →
/// создать «Входящие», если их ещё нет.
Future<SyncServices> startSync(
  AppDatabase db, {
  required AppClock clock,
  required IdGenerator ids,
  required NodeMarker marker,
  ProjectorRegistry? registry,
}) async {
  final store = DriftOpStore(db, registry: registry);
  final meta = LocalMetaDao(db);
  if (await store.needsReproject()) await store.reproject();

  final identity = decideNodeIdentity(
    stored: await meta.nodeId(),
    marked: await marker.read(),
    ids: ids,
  );
  final engine = MergeEngine(
    nodeId: identity.nodeId,
    store: store,
    nowMs: clock.nowMs,
    newOpId: ids.next,
    silentFields: silentFields,
    initialClock: await _startClock(identity.nodeId, meta, store),
  );
  final mutator = Mutator(engine: engine, store: store, meta: meta, ids: ids);

  if (identity.isNew) {
    // Одной транзакцией: если запуск оборвётся, база останется со старым id,
    // и следующий запуск повторит всё заново.
    await store.transaction(() async {
      final uploadedUpTo = await meta.uploadedUpTo();
      await meta.setNodeId(identity.nodeId);
      final previous = identity.previousNodeId;
      if (previous != null) {
        // Водяной знак относится к прежнему узлу: новый ещё ничего не выгружал.
        await meta.removeUploadedUpTo();
        await mutator.adoptUnsyncedOps(previous, uploadedUpTo);
      }
    });
    await marker.write(identity.nodeId);
  }

  final inbox = await store.fieldValue(
    EntityTypes.project,
    inboxProjectId,
    ProjectFields.isInbox,
  );
  if (inbox == null) {
    await mutator.update(
      EntityTypes.project,
      inboxProjectId,
      inboxProjectFields,
    );
  }

  return SyncServices._(
    db: db,
    store: store,
    meta: meta,
    engine: engine,
    mutator: mutator,
    identity: identity,
    clock: clock,
    ids: ids,
  );
}

/// Часы движка при запуске: позже всего, что уже было.
///
/// Максимум из сохранённых часов и самой поздней метки журнала по всем узлам.
/// Свои ops нужны для водяного знака выгрузки (иначе транспорт откажется
/// выгружать), чужие — чтобы правка после перезапуска побеждала уже
/// увиденные значения, а не проигрывала им по LWW.
Future<Hlc> _startClock(
  String nodeId,
  LocalMetaDao meta,
  DriftOpStore store,
) async {
  var wall = 0;
  var counter = 0;
  for (final hlc in [await meta.hlc(), await store.maxHlc()]) {
    if (hlc == null) continue;
    if (hlc.wallMs > wall || (hlc.wallMs == wall && hlc.counter > counter)) {
      wall = hlc.wallMs;
      counter = hlc.counter;
    }
  }
  return Hlc(wallMs: wall, counter: counter, nodeId: nodeId);
}

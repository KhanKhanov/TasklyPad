import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:oplog_sync/oplog_sync.dart';

import 'folder_sync.dart';
import 'sync_services.dart';

/// Синхронизация приложения с общей папкой: проход, выбор и смена папки,
/// список устройств, пересборка базы. Без Flutter и таймеров — их держит
/// состояние экрана настроек; здесь — то, что проверяется обычными тестами.
class SyncRunner {
  SyncRunner({
    required this._services,
    required this._openFs,
    this._deviceInfo = const {},
  });

  static final Logger _log = Logger();

  final SyncServices _services;

  /// Файловая система выбранной папки: на Windows — `IoSyncFs`, в тестах —
  /// временная папка или память.
  final SyncFs Function(String path) _openFs;

  /// Поля `info.json` этого устройства: имя компьютера, платформа, профиль.
  final Map<String, Object?> _deviceInfo;

  // Один FolderSync на папку: у него своя аренда (владелец — этот запуск).
  String? _syncPath;
  FolderSync? _sync;

  /// Выбранная папка или `null` — синхронизация не настроена.
  Future<String?> folderPath() => _services.meta.folderPath();

  /// Время последней удачной синхронизации или `null`.
  Future<DateTime?> lastSync() async {
    final ms = await _services.meta.lastSyncMs();
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Синхронизировать с выбранной папкой. `null` — папка не выбрана или
  /// синхронизацию этой базы уже ведёт другой проход (аренда занята).
  ///
  /// Ошибки транспорта пробрасываются: `SyncFormatException` (папка новее
  /// приложения), ошибки чтения и записи папки.
  Future<FolderSyncReport?> syncNow() async {
    final path = await folderPath();
    if (path == null) return null;
    final report = await _folderSync(path).syncOnce();
    if (report != null) {
      await _services.meta.setLastSyncMs(_services.clock.nowMs());
    }
    return report;
  }

  /// Выбрать папку (первый раз, смена — docs/plans/m2-core-app.md, решение
  /// 12 — или та же заново, когда она пропала) и сразу синхронизироваться с
  /// ней. Папка забывается (`SyncStateStore.forgetFolder`): пока с ней не
  /// было прохода, он может создать в ней папку синхронизации (SYNC_DESIGN
  /// «Транспорт A»), а курсоры и водяной знак сбрасываются, даже если это та
  /// же физическая папка под другим путём.
  ///
  /// Правки узлов [retired] — устройств, которые пользователь отметил как
  /// больше не используемые, — переиздаются от этого узла с исходным временем
  /// (`MergeEngine.adopt`): сами они в новую папку уже не придут. Остальные
  /// устройства переключатся на новую папку и выгрузят свои правки сами.
  /// Прежняя папка не меняется. Возвращает [FolderChange].
  ///
  /// Переиздаётся только то, что уже в журнале, поэтому перед ним — последний
  /// проход с прежней папкой: иначе правки, которые выбывшее устройство
  /// выгрузило после нашего прошлого прохода, остались бы только в ней.
  /// Чанк отмеченного узла не прочитан или прежняя папка недоступна целиком
  /// (`SyncFolderMissingException`, сбой чтения, папка новее приложения) —
  /// [RetiredUnreadException], папка не меняется. По виду ошибки нельзя понять, пройдёт ли она сама: обрезанный
  /// файл одинаков при докачке и при порче, а часы узла, ушедшие вперёд,
  /// догоняются. Поэтому решает пользователь: подождать или сменить с
  /// [force] — тогда переиздаётся прочитанное, а узел попадает в
  /// [FolderChange.unreadable].
  ///
  /// Переиздание — до первого прохода с новой папкой, а не после: копии
  /// сохраняют исходное время, и после прохода водяной знак выгрузки стоял бы
  /// уже позади них — копии с более ранним временем не выгрузились бы
  /// никогда. Первый проход с другой папкой сбрасывает водяной знак и
  /// выгружает весь свой журнал вместе с копиями.
  ///
  /// Бросает [SyncBusyException], если последний проход с прежней папкой не
  /// состоялся: аренду держит другой проход. Сбой первого прохода с новой
  /// папкой не бросается, а возвращается в [FolderChange.error]: папка и
  /// копии уже сохранены и выгрузятся следующим проходом, а итог переиздания
  /// пользователь должен увидеть.
  Future<FolderChange> setFolder(
    String path, {
    Set<String> retired = const {},
    bool force = false,
  }) async {
    var unreadable = const <String>{};
    if (retired.isNotEmpty) {
      final Object? cause;
      (unreadable, cause) = await _lastPass(retired);
      if (unreadable.isNotEmpty && !force) {
        throw RetiredUnreadException(unreadable, cause: cause);
      }
    }
    final adopted = <String>{};
    // Одной транзакцией, путь — последним: прерванная смена (закрыли
    // приложение, сбой записи) не оставит новую папку без части копий —
    // повторный выбор той же папки иначе был бы уже невозможен.
    await _services.mutator.batch(() async {
      await _services.syncState.forgetFolder();
      for (final node in retired) {
        if (await _services.mutator.adoptUnsyncedOps(node, null) > 0) {
          adopted.add(node);
        }
      }
      await _services.meta.setFolderPath(path);
    });
    Object? error;
    var issues = 0;
    try {
      final report = await syncNow();
      if (report == null) {
        error = const SyncBusyException();
      } else {
        issues = report.issues.length;
      }
    } on Object catch (e, stackTrace) {
      // Широко, вместе с Error: смена уже сохранена, и итог переиздания
      // важнее, чем проброс ошибки.
      _log.e(
        'Папка сменена, первый проход с ней не удался',
        error: e,
        stackTrace: stackTrace,
      );
      error = e;
    }
    return (
      adopted: adopted,
      unreadable: unreadable,
      issues: issues,
      error: error,
    );
  }

  /// Последний проход с прежней папкой: отмеченные узлы [retired], чьи правки
  /// прочитаны не все, и причина, если папка недоступна целиком — тогда не
  /// прочитан никто из них. Пропавшую прежнюю папку транспорт не создаёт
  /// заново (`SyncFolderMissingException`).
  Future<(Set<String>, Object?)> _lastPass(Set<String> retired) async {
    // Прежней папки нет — прочитать отмеченных негде.
    if (await folderPath() == null) return (retired, null);
    final FolderSyncReport? report;
    try {
      report = await syncNow();
    } on Exception catch (e) {
      return (retired, e);
    }
    // Error (ошибка в коде) пробрасывается: смена не начинается, данные целы.
    if (report == null) throw const SyncBusyException();
    return (
      {
        for (final issue in report.issues)
          if (retired.contains(issue.nodeId)) issue.nodeId,
      },
      null,
    );
  }

  /// Устройства в выбранной папке — из их `info.json`. Нечитаемый или
  /// неразобранный файл даёт устройство только с id. Папки нет (удалена,
  /// диск отключён) — [SyncFolderMissingException], а не пустой список: в
  /// диалоге смены папки это «устройства не прочитаны», а не «их нет».
  Future<List<SyncDevice>> devices() async {
    final path = await folderPath();
    if (path == null) return const [];
    final fs = _openFs(path);
    if (!await fs.exists('$syncFolderName/format.json')) {
      throw const SyncFolderMissingException('$syncFolderName/format.json');
    }
    final devices = <SyncDevice>[];
    for (final node in await fs.list('$syncFolderName/nodes')) {
      Map<String, Object?> info = const {};
      try {
        final json = jsonDecode(
          await fs.readString('$syncFolderName/nodes/$node/info.json'),
        );
        if (json is Map<String, Object?>) info = json;
      } on Object {
        // info.json — справка для людей: без него устройство всё равно видно.
      }
      devices.add(
        SyncDevice(
          nodeId: node,
          name: info['device'] is String ? info['device']! as String : null,
          platform: info['platform'] is String
              ? info['platform']! as String
              : null,
          profile: info['profile'] is String
              ? info['profile']! as String
              : null,
          updated: info['updated_ms'] is int
              ? DateTime.fromMillisecondsSinceEpoch(
                  info['updated_ms']! as int,
                  isUtc: true,
                )
              : null,
          isThisDevice: node == _services.nodeId,
        ),
      );
    }
    return devices;
  }

  /// Другие узлы из журнала этого устройства — для «Создать папку заново»:
  /// папки нет, и выбывшие устройства видны только по их правкам (решение
  /// пользователя 5А к коммиту 2а M2.3). Имени нет — `info.json` пропал вместе
  /// с папкой; [SyncDevice.lastEdit] — время последней правки. Новые первыми.
  Future<List<SyncDevice>> journalDevices() async {
    final nodes = await _services.store.lastHlcByNode();
    final previous = await _services.meta.previousNodeIds();
    return [
      for (final MapEntry(key: node, value: hlc) in nodes.entries)
        if (node != _services.nodeId)
          SyncDevice(
            nodeId: node,
            isThisDevice: false,
            isFormerThisDevice: previous.contains(node),
            lastEdit: DateTime.fromMillisecondsSinceEpoch(
              hlc.wallMs,
              isUtc: true,
            ),
          ),
    ]..sort((x, y) => y.lastEdit!.compareTo(x.lastEdit!));
  }

  /// Пересобрать проекции и конфликты из журнала («Пересобрать базу из
  /// журнала»). Журнал не меняется; результат обязан совпасть с текущим.
  Future<void> rebuild() => _services.engine.rebuild();

  FolderSync _folderSync(String path) {
    if (_syncPath != path) {
      _syncPath = path;
      _sync = _services.folderSync(_openFs(path), deviceInfo: _deviceInfo);
    }
    return _sync!;
  }
}

/// Итог смены папки: [adopted] — узлы, чьи правки переизданы (у отмеченного
/// узла все поля могли быть уже переписаны другими); [unreadable] — отмеченные
/// узлы, часть правок которых прочитать не удалось (смена с `force`);
/// [issues] — файлы устройств, которые первый проход с
/// новой папкой не прочитал (как `FolderSyncReport.issues`); [error] — этот
/// проход не удался (папка уже сменена).
typedef FolderChange = ({
  Set<String> adopted,
  Set<String> unreadable,
  int issues,
  Object? error,
});

/// Устройство в папке синхронизации — строка списка «Устройства».
final class SyncDevice {
  const SyncDevice({
    required this.nodeId,
    required this.isThisDevice,
    this.name,
    this.platform,
    this.profile,
    this.updated,
    this.lastEdit,
    this.isFormerThisDevice = false,
  });

  final String nodeId;
  final bool isThisDevice;

  /// Имя компьютера или телефона из `info.json`.
  final String? name;
  final String? platform;

  /// Профиль данных (`--profile`): на одном ПК их может быть несколько.
  final String? profile;

  /// Когда устройство последний раз выгружало свои правки (`info.json`).
  final DateTime? updated;

  /// Время его последней правки в журнале этого устройства — у устройств
  /// из журнала ([SyncRunner.journalDevices]), у которых нет `info.json`.
  final DateTime? lastEdit;

  /// Прежний id этого устройства: база скопирована (перенос, резервная
  /// копия). Отмечать, если копией-источником больше не пользуются.
  final bool isFormerThisDevice;
}

/// Смена папки не начата: последний проход с прежней папкой не прочитал часть
/// правок отмеченных выбывших устройств — облако ещё докачивает файлы, файл
/// повреждён, часы устройства ушли вперёд или прежняя папка недоступна.
/// Пользователь ждёт или меняет папку с `force`.
final class RetiredUnreadException implements Exception {
  const RetiredUnreadException(this.nodes, {this.cause});

  final Set<String> nodes;

  /// Ошибка прохода, если прежняя папка недоступна целиком.
  final Object? cause;

  @override
  String toString() => 'RetiredUnreadException($nodes, $cause)';
}

/// Проход не состоялся: синхронизацию этой базы уже ведёт другой проход.
final class SyncBusyException implements Exception {
  const SyncBusyException();

  @override
  String toString() => 'SyncBusyException';
}

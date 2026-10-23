import 'dart:convert';

import 'fs.dart';
import 'hlc.dart';
import 'merge_engine.dart';
import 'op.dart';
import 'sync_state.dart';

/// Обмен ops через общую папку (OneDrive, Google Drive, Syncthing, …).
///
/// Раскладка (docs/SYNC_DESIGN.md):
/// ```
/// <root>/format.json                 { "v": 1, "folder_id": "…" }
/// <root>/nodes/<node_id>/info.json   устройство, последний чанк, время
/// <root>/nodes/<node_id>/000001.ndjson …   чанки ops, неизменяемы
/// ```
/// Узел пишет только в свою папку, чужие читает. Каждая выгрузка — новый
/// чанк с номером «максимальный существующий + 1»: существующий файл никогда
/// не перезаписывается. Последняя строка чанка — `{"end": N}` с числом ops:
/// без неё чанк считается недокачанным. Чанки каждого узла читаются строго по
/// порядку номеров; курсор узла сдвигается, только когда чанк применён целиком.
///
/// Свою папку узел тоже читает (по своему курсору): после восстановления базы
/// из резервной копии так возвращаются свои ops, выгруженные после копии.
///
/// На одну базу — один [MergeEngine] и один транспорт: два экземпляра
/// (например, UI и фоновая задача Android) могут записать чанк с одним номером.
final class FolderTransport {
  FolderTransport({
    required this.fs,
    required this.engine,
    required this.state,
    this.root = '',
    this.deviceInfo = const {},
    this.maxChunkBytes = defaultMaxChunkBytes,
  });

  final SyncFs fs;
  final MergeEngine engine;
  final SyncStateStore state;

  /// Путь к `planner-sync` относительно корня [fs].
  final String root;

  /// Дополнительные поля `info.json`: имя устройства, платформа.
  final Map<String, Object?> deviceInfo;

  /// Порог размера чанка в байтах UTF-8. Ops одной правки (общий HLC) не
  /// делятся между чанками, поэтому чанк может выйти больше порога.
  final int maxChunkBytes;

  /// Версия формата папки. Меняется только с миграцией.
  static const int formatVersion = 1;

  static const int defaultMaxChunkBytes = 1024 * 1024;

  /// Запас под завершающую строку `{"end":N}\n`.
  static const int _trailerBytes = 24;

  /// Имя чанка: номер из 6+ цифр. Копии, которые создают облачные клиенты при
  /// конфликте файлов («000003 (1).ndjson»), под шаблон не подходят и не читаются.
  static final RegExp _chunkName = RegExp(r'^(\d{6,})\.ndjson$');

  Future<FolderSyncReport>? _running;

  /// Вчитать новые чанки всех узлов, затем выгрузить свои новые ops.
  ///
  /// Повторный вызов во время синхронизации возвращает тот же результат, а
  /// не запускает вторую параллельно. Бросает [SyncFormatException], если
  /// папка записана неизвестной версией формата, — тогда ничего не пишется.
  /// Нечитаемый чужой файл не останавливает синхронизацию — он попадает в
  /// [FolderSyncReport.issues]; ошибка записи своего чанка пробрасывается.
  Future<FolderSyncReport> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<FolderSyncReport> _sync() async {
    final report = FolderSyncReport();
    final folderId = await _ensureFormat();
    if (await state.folderId() != folderId) {
      // Другая папка (или её пересоздали): старые курсоры и «выгружено до»
      // к ней не относятся — читаем всё и выгружаем весь свой журнал заново.
      await state.resetForFolder(folderId);
    }
    for (final nodeId in await fs.list(_path('nodes'))) {
      await _download(nodeId, report);
    }
    await _upload(report);
    // Конфликт из раннего чанка мог быть разрешён в позднем — не уведомлять.
    final conflicts = report.received.conflicts;
    if (conflicts.isNotEmpty) {
      final resolved = {
        for (final c in await engine.store.conflicts())
          if (c.resolved) c.id,
      };
      conflicts.removeWhere((c) => resolved.contains(c.id));
    }
    return report;
  }

  String _path(String relative) => root.isEmpty ? relative : '$root/$relative';

  static String _chunkFile(int seq) =>
      '${seq.toString().padLeft(6, '0')}.ndjson';

  /// Проверить `format.json` (создать, если папка новая) и вернуть id папки.
  Future<String> _ensureFormat() async {
    final path = _path('format.json');
    if (!await fs.exists(path)) {
      // Уникальный id папки берём у генератора op_id (в приложении — UUIDv7).
      final folderId = engine.newOpId();
      await fs.writeString(
        path,
        '${jsonEncode({'v': formatVersion, 'folder_id': folderId})}\n',
      );
      return folderId;
    }
    final text = await fs.readString(path);
    final json = _tryDecode(text);
    final version = switch (json) {
      {'v': final int v} when v >= 1 => v,
      _ => null,
    };
    if (version != null && version > formatVersion) {
      throw SyncFormatException(
        'папка записана форматом v$version, приложение понимает до '
        'v$formatVersion — обновите приложение на этом устройстве',
      );
    }
    final folderId = switch (json) {
      {'folder_id': final String id} when id.isNotEmpty => id,
      _ => null,
    };
    if (version == null || folderId == null) {
      throw SyncFormatException('format.json не разобран: ${text.trim()}');
    }
    return folderId;
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Номера чанков в папке узла → имена файлов.
  Future<Map<int, String>> _chunks(String nodeId) async {
    final result = <int, String>{};
    for (final name in await fs.list(_path('nodes/$nodeId'))) {
      final match = _chunkName.firstMatch(name);
      if (match != null) result[int.parse(match.group(1)!)] = name;
    }
    return result;
  }

  Future<void> _download(String nodeId, FolderSyncReport report) async {
    var cursor = await state.chunkCursor(nodeId);
    final Map<int, String> chunks;
    try {
      chunks = await _chunks(nodeId);
    } on Exception catch (e) {
      report.issues.add(
        ChunkIssue(
          nodeId: nodeId,
          seq: cursor + 1,
          kind: ChunkIssueKind.io,
          detail: '$e',
        ),
      );
      return;
    }
    final pending = chunks.keys.where((seq) => seq > cursor).toList()..sort();
    for (final seq in pending) {
      if (seq != cursor + 1) {
        // Ops узла применяются только по порядку: перескочив недокачанный
        // чанк, мы бы потеряли его навсегда — курсор назад не идёт.
        report.issues.add(
          ChunkIssue(
            nodeId: nodeId,
            seq: cursor + 1,
            kind: ChunkIssueKind.missing,
          ),
        );
        return;
      }
      final ops = await _readChunk(nodeId, seq, chunks[seq]!, report);
      if (ops == null) return;
      final applied = await engine.applyAll(ops);
      report.received
        ..applied += applied.applied
        ..duplicate += applied.duplicate
        ..stale += applied.stale
        ..rejected += applied.rejected
        ..conflicts.addAll(applied.conflicts);
      if (applied.rejected > 0) {
        // Остальные ops чанка уже применены; при следующем чтении они
        // окажутся дубликатами, а отклонённые получат второй шанс.
        report.issues.add(
          ChunkIssue(
            nodeId: nodeId,
            seq: seq,
            kind: ChunkIssueKind.rejected,
            detail: 'отклонено ops: ${applied.rejected}',
          ),
        );
        return;
      }
      cursor = seq;
      await state.setChunkCursor(nodeId, seq);
    }
  }

  /// Ops чанка или `null`, если читать его сейчас нельзя (причина — в отчёте).
  Future<List<Op>?> _readChunk(
    String nodeId,
    int seq,
    String name,
    FolderSyncReport report,
  ) async {
    void issue(ChunkIssueKind kind, [String detail = '']) => report.issues.add(
      ChunkIssue(nodeId: nodeId, seq: seq, kind: kind, detail: detail),
    );

    final String text;
    try {
      text = await fs.readString(_path('nodes/$nodeId/$name'));
    } on Exception catch (e) {
      // Файл заблокирован, ещё не скачан облаком, не UTF-8, …
      issue(ChunkIssueKind.io, '$e');
      return null;
    }
    // Мы пишем чанк целиком: '\n' в конце и завершающая строка с числом ops.
    // Чего-то нет — файл ещё докачивается (обрыв мог прийтись и ровно на
    // границу строк). Прочитаем в следующий раз.
    final lines = text.split('\n');
    final expected = lines.length < 2 || lines.last.isNotEmpty
        ? null
        : switch (_tryDecode(lines[lines.length - 2])) {
            {'end': final int count} => count,
            _ => null,
          };
    if (expected == null) {
      issue(ChunkIssueKind.incomplete);
      return null;
    }
    final ops = <Op>[];
    for (var i = 0; i < lines.length - 2; i++) {
      if (lines[i].trim().isEmpty) continue;
      try {
        final json = jsonDecode(lines[i]);
        if (json is! Map<String, Object?>) {
          throw const FormatException('строка не JSON-объект');
        }
        final op = Op.fromJson(json);
        if (op.nodeId != nodeId || op.hlc.nodeId != nodeId) {
          throw FormatException('op узла ${op.nodeId} в папке узла $nodeId');
        }
        ops.add(op);
      } on FormatException catch (e) {
        issue(ChunkIssueKind.malformed, 'строка ${i + 1}: ${e.message}');
        return null;
      }
    }
    if (ops.length != expected) {
      issue(
        ChunkIssueKind.malformed,
        'ops в чанке: ${ops.length}, в завершающей строке: $expected',
      );
      return null;
    }
    return ops;
  }

  Future<void> _upload(FolderSyncReport report) async {
    final me = engine.nodeId;
    final dir = _path('nodes/$me');
    final uploadedUpTo = await state.uploadedUpTo();
    if (uploadedUpTo != null && engine.clock < uploadedUpTo) {
      // Новые ops получили бы HLC ниже водяного знака и не выгрузились бы
      // никогда. Значит, приложение не восстановило часы движка.
      throw StateError(
        'Часы движка ${engine.clock} отстают от уже выгруженного '
        '$uploadedUpTo: состояние HLC не восстановлено при запуске',
      );
    }
    final ops = await engine.store.opsOfNodeAfter(me, uploadedUpTo);
    final existing = await _chunks(me);
    var seq = existing.isEmpty
        ? 0
        : existing.keys.reduce((a, b) => a > b ? a : b);
    if (ops.isEmpty) {
      if (!await fs.exists('$dir/info.json')) await _writeInfo(dir, seq);
      return;
    }
    for (final chunk in _split(ops)) {
      seq++;
      // Защита от перезаписи, если список файлов отстал от диска.
      while (await fs.exists('$dir/${_chunkFile(seq)}')) {
        seq++;
      }
      chunk.text.write('${jsonEncode({'end': chunk.count})}\n');
      await fs.writeString('$dir/${_chunkFile(seq)}', chunk.text.toString());
      report
        ..uploaded += chunk.count
        ..writtenChunks.add(seq);
      // Безопасно: все ops с HLC чанка лежат в нём же (см. [_split]).
      await state.setUploadedUpTo(chunk.last);
      // Свой чанк читать незачем — если все предыдущие уже прочитаны.
      if (await state.chunkCursor(me) == seq - 1) {
        await state.setChunkCursor(me, seq);
      }
    }
    await _writeInfo(dir, seq);
  }

  /// Делит ops (отсортированные по HLC) на чанки по размеру. Ops с одним HLC
  /// (одна правка) всегда в одном чанке: иначе при сбое после первого чанка
  /// водяной знак уже равнялся бы их HLC, и хвост правки не выгрузился бы.
  List<_Chunk> _split(List<Op> ops) {
    final chunks = <_Chunk>[];
    _Chunk? current;
    for (final op in ops) {
      final line = '${jsonEncode(op.toJson())}\n';
      final bytes = utf8.encode(line).length;
      if (current == null ||
          (current.count > 0 &&
              op.hlc != current.last &&
              current.bytes + bytes + _trailerBytes > maxChunkBytes)) {
        current = _Chunk();
        chunks.add(current);
      }
      current
        ..text.write(line)
        ..bytes += bytes
        ..count += 1
        ..last = op.hlc;
    }
    return chunks;
  }

  Future<void> _writeInfo(String dir, int lastSeq) => fs.writeString(
    '$dir/info.json',
    '${jsonEncode({...deviceInfo, 'node_id': engine.nodeId, 'format': formatVersion, 'last_seq': lastSeq, 'updated_ms': engine.nowMs()})}\n',
  );
}

final class _Chunk {
  final StringBuffer text = StringBuffer();
  int bytes = 0;
  int count = 0;
  late Hlc last;
}

/// Итог одного [FolderTransport.sync].
final class FolderSyncReport {
  /// Применение прочитанных ops всех узлов. [ApplyReport.conflicts] — новые
  /// конфликты, не разрешённые к концу синхронизации.
  final ApplyReport received = ApplyReport();

  /// Сколько своих ops записано в папку.
  int uploaded = 0;

  /// Номера записанных своих чанков.
  final List<int> writtenChunks = <int>[];

  /// Чанки, которые не прочитаны в этот раз (курсор узла не сдвинут).
  final List<ChunkIssue> issues = <ChunkIssue>[];

  @override
  String toString() =>
      'FolderSyncReport(received: $received, uploaded: $uploaded, '
      'chunks: $writtenChunks, issues: $issues)';
}

/// Почему чанк узла не прочитан.
enum ChunkIssueKind {
  /// Чанка с очередным номером нет, а следующие есть: облачный клиент ещё
  /// не докачал его (или файл удалили — тогда узел стоит до разбирательства).
  missing,

  /// Нет '\n' в конце или завершающей строки `{"end": N}` — ещё докачивается.
  incomplete,

  /// Строка не разбирается как op, op чужого узла лежит не в своей папке
  /// или число ops не совпадает с завершающей строкой.
  malformed,

  /// Часть ops отклонена: часы автора опережают наши больше [Hlc.maxDrift].
  rejected,

  /// Файл или папку не удалось прочитать: заблокирован, не скачан, не UTF-8.
  io,
}

/// Чанк [seq] узла [nodeId], который придётся перечитать позже.
final class ChunkIssue {
  const ChunkIssue({
    required this.nodeId,
    required this.seq,
    required this.kind,
    this.detail = '',
  });

  final String nodeId;
  final int seq;
  final ChunkIssueKind kind;
  final String detail;

  @override
  String toString() =>
      'ChunkIssue($nodeId/${seq.toString().padLeft(6, '0')}: ${kind.name}'
      '${detail.isEmpty ? '' : ', $detail'})';
}

/// Папка синхронизации записана форматом, которого это приложение не знает.
/// Синхронизация остановлена до обновления приложения.
final class SyncFormatException implements Exception {
  const SyncFormatException(this.message);

  final String message;

  @override
  String toString() => 'SyncFormatException: $message';
}

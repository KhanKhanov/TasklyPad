import 'dart:io';

import '../core/ids.dart';

/// Метка «эта база принадлежит этому устройству» — файл вне базы.
///
/// Лежит там, куда копия базы не попадает вместе с ней: на Windows — в
/// Local AppData (база — в Roaming), на Android — в `no_backup` (система не
/// включает её в резервные копии). Абстракция — чтобы тесты не трогали диск.
abstract interface class NodeMarker {
  /// Id узла из метки или `null`, если метки нет.
  Future<String?> read();

  Future<void> write(String nodeId);
}

/// Метка в файле на диске.
final class FileNodeMarker implements NodeMarker {
  FileNodeMarker(this.path);

  final String path;

  @override
  Future<String?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    final text = (await file.readAsString()).trim();
    return text.isEmpty ? null : text;
  }

  @override
  Future<void> write(String nodeId) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('$nodeId\n', flush: true);
  }
}

/// Метка в памяти — для тестов и платформ без отдельной папки.
final class MemoryNodeMarker implements NodeMarker {
  MemoryNodeMarker([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String nodeId) async => value = nodeId;
}

/// Итог опознания узла при запуске.
final class NodeIdentity {
  const NodeIdentity(this.nodeId, {this.isNew = false, this.previousNodeId});

  /// Id узла, под которым это устройство пишет ops.
  final String nodeId;

  /// Id выдан сейчас: его нужно записать в базу и в метку.
  final bool isNew;

  /// Прежний id, если база оказалась копией с другого устройства (или из
  /// резервной копии) и узел получил новый id; иначе `null`.
  final String? previousNodeId;
}

/// Определить id узла по id в базе [stored] и в метке [marked]. Только
/// решение: записывает его запуск движка вместе с остальными шагами.
///
/// Новая база — новый id. Id в базе совпадает с меткой — тот же узел. Метки нет
/// или в ней другой id — база скопирована (перенос на новый ПК, восстановление
/// резервной копии): два устройства под одним id теряли бы правки друг друга,
/// поэтому выдаётся новый id. Ложное срабатывание (метку удалили) безвредно:
/// в папке синхронизации появится ещё один узел.
NodeIdentity decideNodeIdentity({
  required String? stored,
  required String? marked,
  required IdGenerator ids,
}) {
  if (stored != null && stored == marked) return NodeIdentity(stored);
  return NodeIdentity(ids.next(), isNew: true, previousNodeId: stored);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_log.freezed.dart';

/// Сколько записей хранит журнал «Уведомления»; старые стираются.
const int notificationLogLimit = 200;

/// Длина текста записи в символах Unicode (кодовых точках); длиннее —
/// обрезается.
const int notificationTextLimit = 500;

/// Запись журнала «Уведомления»: показанное нижнее уведомление.
@freezed
abstract class NotificationEntry with _$NotificationEntry {
  const factory NotificationEntry({
    /// Растёт с каждой записью и не повторяется даже после «Очистить всё».
    required int id,

    /// Когда показано — Unix-миллисекунды UTC (часы приложения).
    required int atMs,

    /// Текст на языке интерфейса в момент показа.
    required String text,
  }) = _NotificationEntry;
}

/// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
/// M5.3a»): все нижние уведомления, от старых к новым, до
/// [notificationLogLimit]. Память устройства, не данные пользователя: не
/// синхронизируется (SYNC_DESIGN «Специальные случаи»). Непрочитанные — с
/// `id` больше [seenId]. «Отменить» в журнале нет — как в Todoist, отмена
/// работает, только пока тост на экране.
@freezed
abstract class NotificationLog with _$NotificationLog {
  const factory NotificationLog({
    @Default(1) int nextId,
    @Default(0) int seenId,
    @Default(<NotificationEntry>[]) List<NotificationEntry> items,
  }) = _NotificationLog;

  const NotificationLog._();

  /// Разбор [json] из `local_meta`; другой формат или несогласованные
  /// значения (id не растут, `next` не больше последнего id, `seen` не меньше
  /// `next`) — исключение: иначе следующая запись получила бы уже занятый id.
  /// Записей сверх [notificationLogLimit] — только последние.
  factory NotificationLog.fromJson(Map<String, Object?> json) {
    if (json case {
      'v': 1,
      'next': final int next,
      'seen': final int seen,
      'items': final List<Object?> raw,
    }) {
      final items = [
        for (final item in raw)
          if (item case {
            'id': final int id,
            'at': final int at,
            'text': final String text,
          })
            NotificationEntry(id: id, atMs: at, text: text)
          else
            throw FormatException('Запись журнала не разобрана: $item'),
      ];
      for (var i = 1; i < items.length; i++) {
        if (items[i].id <= items[i - 1].id) {
          throw const FormatException('id журнала не растут');
        }
      }
      if ((items.isNotEmpty && next <= items.last.id) ||
          seen >= next ||
          seen < 0) {
        throw FormatException('Счётчики журнала не сходятся: $next, $seen');
      }
      return NotificationLog(
        nextId: next,
        seenId: seen,
        items: items.length > notificationLogLimit
            ? items.sublist(items.length - notificationLogLimit)
            : items,
      );
    }
    throw FormatException('Журнал не разобран: ${json['v']}');
  }

  /// Вид для `local_meta`: один ключ — запись атомарна, счётчик и записи не
  /// расходятся.
  Map<String, Object?> toJson() => {
    'v': 1,
    'next': nextId,
    'seen': seenId,
    'items': [
      for (final e in items) {'id': e.id, 'at': e.atMs, 'text': e.text},
    ],
  };

  /// Сколько записей ещё не видели — счётчик на вкладке.
  int get unread => items.where((e) => e.id > seenId).length;

  /// Добавить показанное уведомление [text] в момент [atMs]; сверх
  /// [notificationLogLimit] стираются самые старые.
  NotificationLog add(String text, int atMs) {
    final runes = text.runes;
    final cut = runes.length > notificationTextLimit
        ? String.fromCharCodes(runes.take(notificationTextLimit))
        : text;
    final all = [
      ...items,
      NotificationEntry(id: nextId, atMs: atMs, text: cut),
    ];
    return copyWith(
      nextId: nextId + 1,
      items: all.length > notificationLogLimit
          ? all.sublist(all.length - notificationLogLimit)
          : all,
    );
  }

  /// Удалить запись [id]; непрочитанная уходит и из счётчика.
  NotificationLog remove(int id) => copyWith(
    items: [
      for (final e in items)
        if (e.id != id) e,
    ],
  );

  /// «Очистить всё»: записей нет, нумерация продолжается.
  NotificationLog clear() => copyWith(items: const [], seenId: nextId - 1);

  /// Вкладку открыли — всё прочитано.
  NotificationLog markRead() => copyWith(seenId: nextId - 1);
}

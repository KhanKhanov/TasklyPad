// «Недавно просмотренное» окна поиска (help «Introduction to search»: «Below
// the search bar are tasks, projects, or views you've recently viewed»).
// Память устройства, а не данные пользователя (решение 1А plans/m5 «Решения
// M5.4», SYNC_DESIGN «Специальные случаи»): хранится в `local_meta`, не
// синхронизируется.

/// Записей не больше (в help число не указано — допущение, О-69).
const int recentlyViewedLimit = 5;

/// Что открывали: задачу, проект, метку, фильтр или вид.
enum ViewedKind { task, project, label, filter, inbox, today, upcoming }

/// Просмотренный элемент; [id] — у задачи, проекта, метки и фильтра.
final class ViewedItem {
  const ViewedItem(this.kind, [this.id]);

  final ViewedKind kind;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is ViewedItem && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'ViewedItem(${kind.name}, $id)';
}

/// Список просмотренного, последнее — первым.
final class RecentlyViewed {
  const RecentlyViewed([this.items = const []]);

  /// Разбор вида для хранения; чужая версия или битые данные —
  /// [FormatException].
  factory RecentlyViewed.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['v'] != _version) {
      throw FormatException('recently viewed: $json');
    }
    final items = json['items'];
    if (items is! List) throw FormatException('recently viewed items: $items');
    return RecentlyViewed([
      for (final item in items.take(recentlyViewedLimit)) _itemOf(item),
    ]);
  }

  static const int _version = 1;

  final List<ViewedItem> items;

  /// Открыли [item]: он наверху, повтор убран, не больше
  /// [recentlyViewedLimit]. Уже наверху — тот же объект (запись не нужна).
  RecentlyViewed visit(ViewedItem item) {
    if (items.isNotEmpty && items.first == item) return this;
    return RecentlyViewed(
      [
        item,
        for (final i in items)
          if (i != item) i,
      ].take(recentlyViewedLimit).toList(),
    );
  }

  /// Вид для хранения.
  Map<String, Object?> toJson() => {
    'v': _version,
    'items': [
      for (final i in items) {'k': i.kind.name, if (i.id != null) 'id': i.id},
    ],
  };

  static ViewedItem _itemOf(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('recently viewed item: $json');
    }
    final kind = ViewedKind.values.asNameMap()[json['k']];
    final id = json['id'];
    final needsId = switch (kind) {
      ViewedKind.task ||
      ViewedKind.project ||
      ViewedKind.label ||
      ViewedKind.filter => true,
      _ => false,
    };
    if (kind == null || (needsId ? id is! String : id != null)) {
      throw FormatException('recently viewed item: $json');
    }
    return ViewedItem(kind, id as String?);
  }
}

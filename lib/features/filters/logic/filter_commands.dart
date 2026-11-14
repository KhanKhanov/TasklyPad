import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import '../../views/logic/view_options_commands.dart';

/// Действия пользователя над сохранёнными фильтрами («Мои фильтры», help
/// «Introduction to filters») — всё через [Mutator].
///
/// Лимиты — help «Usage limits» ([Limits.filterName], [Limits.filterQuery],
/// [Limits.filters]; О-80). Запрос хранится текстом: синтаксис проверяет
/// окно фильтра при вводе, а не команда — запрос с ошибкой, пришедший с
/// другого устройства, всё равно читается и правится. Одинаковые имена
/// фильтров допустимы: на фильтр по имени запросы не ссылаются (в help не
/// описано — допущение, О-69). Удаление — без отмены, как у метки.
final class FilterCommands {
  FilterCommands({
    required this._mutator,
    required this._read,
    required this._views,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final ViewOptionsCommands _views;

  /// Создать фильтр в конце «Моих фильтров». Описания при создании нет: в
  /// Todoist оно у существующего фильтра (help «Introduction to filters»).
  /// Возвращает id.
  Future<String> add({
    required String name,
    required String query,
    String color = 'charcoal',
    bool isFavorite = false,
  }) async {
    final fields = {
      FilterFields.name: _name(name),
      FilterFields.query: _query(query),
      FilterFields.color: color,
      FilterFields.isFavorite: isFavorite,
    };
    final ws = await _read();
    _checkRoom(ws);
    return _mutator.create(EntityTypes.filter, {
      ...fields,
      FilterFields.orderKey: keyAtEnd([for (final f in ws.filters) f.orderKey]),
    });
  }

  /// Правка из окна фильтра одной записью — сбой не оставит её наполовину.
  /// `null` — поле не менялось; пишутся только изменённые поля.
  Future<void> edit(
    String id, {
    String? name,
    String? query,
    String? description,
    String? color,
    bool? isFavorite,
  }) async {
    final fields = {
      if (name != null) FilterFields.name: _name(name),
      if (query != null) FilterFields.query: _query(query),
      if (description != null)
        FilterFields.description: _description(description),
      FilterFields.color: ?color,
      FilterFields.isFavorite: ?isFavorite,
    };
    _alive(await _read(), id);
    if (fields.isEmpty) return;
    await _mutator.update(EntityTypes.filter, id, fields);
  }

  /// Описание под именем над результатами (help «Introduction to filters»).
  Future<void> setDescription(String id, String description) =>
      edit(id, description: description);

  Future<void> setFavorite(String id, bool favorite) =>
      edit(id, isFavorite: favorite);

  /// Перетаскивание в «Моих фильтрах»: сразу после [afterId] (`null` —
  /// первым; фильтра [afterId] нет — в конец), help «Introduction to
  /// filters»: «drag and drop». После самого себя — ничего не меняется.
  Future<void> reorder(String id, {String? afterId}) =>
      _mutator.batch(() async {
        final ws = await _read();
        _alive(ws, id);
        if (afterId == id) return;
        final all = ws.filters;
        final others = [
          for (final f in all)
            if (f.id != id) f,
        ];
        final after = others.indexWhere((f) => f.id == afterId);
        final index = afterId == null
            ? 0
            : after < 0
            ? others.length
            : after + 1;
        if (all.indexWhere((f) => f.id == id) == index) return;
        final keys = insertionKeys(
          [for (final f in others) f.orderKey],
          index,
          1,
        );
        for (final (i, key) in keys.rekeyed.indexed) {
          if (key == null) continue;
          await _mutator.update(EntityTypes.filter, others[i].id, {
            FilterFields.orderKey: key,
          });
        }
        await _mutator.update(EntityTypes.filter, id, {
          FilterFields.orderKey: keys.inserted.single,
        });
      });

  /// Дубликат сразу после фильтра: запрос, описание, цвет и «Отображение»;
  /// избранное — нет, как у дубликата проекта. [name] — имя копии из
  /// интерфейса («Копия …»). Дубликата фильтра в help нет — допущение (О-69).
  /// Соседи с тем же ключом (два устройства добавили офлайн в конец)
  /// получают новые ключи — иначе копия встала бы после них.
  Future<String> duplicate(String id, {required String name}) =>
      _mutator.batch(() async {
        final ws = await _read();
        final source = _alive(ws, id);
        _checkRoom(ws);
        final text = _name(Limits.clip(name.trim(), Limits.filterName));
        final all = ws.filters;
        final keys = insertionKeys(
          [for (final f in all) f.orderKey],
          all.indexWhere((f) => f.id == id) + 1,
          1,
        );
        for (final (i, key) in keys.rekeyed.indexed) {
          if (key == null) continue;
          await _mutator.update(EntityTypes.filter, all[i].id, {
            FilterFields.orderKey: key,
          });
        }
        final copy = await _mutator.create(EntityTypes.filter, {
          FilterFields.name: text,
          FilterFields.query: source.query,
          if (source.description.isNotEmpty)
            FilterFields.description: source.description,
          FilterFields.color: source.color,
          FilterFields.orderKey: keys.inserted.single,
        });
        await _views.copy(ViewType.filter, id, copy);
        return copy;
      });

  /// Удалить (tombstone) одной op; «Отображение» фильтра остаётся в журнале
  /// и ни на что не влияет.
  Future<void> delete(String id) async {
    _alive(await _read(), id);
    await _mutator.delete(EntityTypes.filter, id);
  }

  static SavedFilter _alive(Workspace ws, String id) =>
      ws.filter(id) ?? (throw const CommandRejected(RejectReason.notFound));

  static void _checkRoom(Workspace ws) {
    if (ws.filters.length >= Limits.filters) {
      throw const CommandRejected(RejectReason.tooManyFilters);
    }
  }

  static String _name(String name) {
    final text = name.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    return Limits.checkLength(text, Limits.filterName);
  }

  static String _query(String query) {
    final text = query.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyQuery);
    return Limits.checkLength(text, Limits.filterQuery);
  }

  /// Описание из одних пробелов — пустое, как у проекта; лимит — как у
  /// описания проекта (в help для фильтра не указан — допущение, О-69).
  static String _description(String description) =>
      Limits.checkLength(storedDescription(description), Limits.description);
}

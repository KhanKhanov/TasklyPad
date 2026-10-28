import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../domain/conflicts.dart';
import '../../../domain/models.dart';
import '../../../domain/theme_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../../sync/sync_runner.dart';
import '../../common/ui/ui_kit.dart';
import '../../settings/ui/sync_devices.dart';
import '../../settings/ui/theme_texts.dart';

// Тексты карточек «Конфликты»: что за сущность, какое поле, какое значение.
// Чистые функции от l10n — проверяются табличным тестом без виджетов.

/// Заголовок карточки: «Задача „Отчёт“», «Метка „дом“ у задачи „Отчёт“».
String conflictEntityTitle(AppLocalizations l10n, ConflictCard card) {
  final title = card.isInbox
      ? l10n.inbox
      : _nonEmpty(card.title) ?? l10n.conflictUntitled;
  return switch (card.entity) {
    ConflictEntity.task => l10n.conflictEntityTask(title),
    ConflictEntity.project => l10n.conflictEntityProject(title),
    ConflictEntity.section => l10n.conflictEntitySection(title),
    ConflictEntity.label => l10n.conflictEntityLabel(title),
    ConflictEntity.taskLabel => l10n.conflictEntityTaskLabel(
      title,
      _nonEmpty(card.ownerTitle) ?? l10n.conflictUntitled,
    ),
    ConflictEntity.settings => l10n.conflictEntitySettings,
    ConflictEntity.other => l10n.conflictEntityOther(title),
  };
}

/// Подпись поля; незнакомое поле — его имя в журнале.
String conflictFieldTitle(AppLocalizations l10n, ConflictValue value) =>
    switch (value.field) {
      ConflictField.name || ConflictField.content => l10n.fieldName,
      ConflictField.description => l10n.fieldDescription,
      ConflictField.project => l10n.fieldProject,
      ConflictField.section => l10n.fieldSection,
      ConflictField.parentTask => l10n.fieldParentTask,
      ConflictField.parentProject => l10n.fieldParent,
      ConflictField.priority => l10n.fieldPriority,
      ConflictField.due => l10n.fieldDue,
      ConflictField.deadline => l10n.fieldDeadline,
      ConflictField.duration => l10n.fieldDuration,
      ConflictField.completed => l10n.fieldCompleted,
      ConflictField.color => l10n.fieldColor,
      ConflictField.favorite => l10n.fieldInFavorites,
      ConflictField.archived => l10n.fieldArchived,
      ConflictField.viewStyle => l10n.fieldViewStyle,
      ConflictField.theme => l10n.themeSection,
      ConflictField.appearance => l10n.themeAppearance,
      ConflictField.deleted || ConflictField.other => value.key,
    };

/// Значение поля текстом. Значение неожиданного вида (поле от более новой
/// версии, повреждённая запись) — его JSON: показать честно лучше, чем упасть.
String conflictValueText(
  AppLocalizations l10n,
  String locale,
  ConflictEntity entity,
  ConflictValue value,
) {
  final v = value.value;
  final text = switch ((value.field, v)) {
    (ConflictField.deleted, final bool deleted) =>
      entity == ConflictEntity.taskLabel
          ? (deleted ? l10n.valueLabelRemoved : l10n.valueLabelAdded)
          : (deleted ? l10n.valueDeleted : l10n.valueRestored),
    (ConflictField.name || ConflictField.content, final String s) =>
      _nonEmpty(s) ?? l10n.valueEmpty,
    (ConflictField.description, final String s) =>
      _nonEmpty(s) ?? l10n.valueEmpty,
    (ConflictField.project, null) => l10n.inbox,
    (ConflictField.section, null) => l10n.noSection,
    (ConflictField.parentTask || ConflictField.parentProject, null) =>
      l10n.noParent,
    (
      ConflictField.project ||
          ConflictField.section ||
          ConflictField.parentTask ||
          ConflictField.parentProject,
      final ConflictRef ref,
    ) =>
      _ref(l10n, ref),
    (ConflictField.priority, final int n) when n >= 1 && n <= 4 =>
      l10n.priorityN(n),
    (ConflictField.due, null) => l10n.noDue,
    (ConflictField.due, final Due due) => _due(locale, due),
    (ConflictField.deadline, null) => l10n.noDeadline,
    (ConflictField.deadline, final String date) => _date(locale, date),
    (ConflictField.duration, null) => l10n.noDuration,
    (ConflictField.duration, final TaskDuration d) => l10n.durationMinutes(
      d.unit == 'day' ? d.amount * 1440 : d.amount,
    ),
    (ConflictField.completed, final bool done) =>
      done ? l10n.valueCompleted : l10n.valueNotCompleted,
    (ConflictField.color, final String key) => colorName(l10n, key),
    (ConflictField.favorite, final bool yes) =>
      yes ? l10n.valueInFavorites : l10n.valueNotInFavorites,
    (ConflictField.archived, final bool yes) =>
      yes ? l10n.valueArchived : l10n.valueNotArchived,
    (ConflictField.viewStyle, 'board') => l10n.viewBoard,
    (ConflictField.viewStyle, 'calendar') => l10n.viewCalendar,
    (ConflictField.viewStyle, 'list') => l10n.viewList,
    // Незнакомая тема (от более новой версии) — её id как есть.
    (ConflictField.theme, final String id) => themeTitle(l10n, id),
    (ConflictField.appearance, final String raw) =>
      switch (ThemeAppearance.parse(raw)) {
        final ThemeAppearance a => appearanceTitle(l10n, a),
        null => null,
      },
    _ => null,
  };
  return text ?? (v == null ? l10n.valueEmpty : jsonEncode(v));
}

String _ref(AppLocalizations l10n, ConflictRef ref) {
  final name = ref.isInbox ? l10n.inbox : _nonEmpty(ref.title);
  if (name == null) return l10n.valueMissing;
  return ref.isDeleted ? l10n.valueDeletedRef(name) : name;
}

/// Срок — абсолютной датой: «Сегодня» во вчерашнем конфликте сбивало бы.
String _due(String locale, Due due) {
  final time = due.time;
  final tz = due.tz;
  return [_date(locale, due.date), ?time, if (tz != null) '($tz)'].join(' ');
}

String _date(String locale, String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : DateFormat.yMMMd(locale).format(parsed);
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s;

/// Текст уведомления о новых карточках: одна — что и какое поле, несколько —
/// сколько.
String conflictNoticeText(AppLocalizations l10n, List<ConflictCard> cards) {
  if (cards.length != 1) return l10n.conflictToastMany(cards.length);
  final card = cards.single;
  final entity = conflictEntityTitle(l10n, card);
  if (card.isDelete) return l10n.conflictToastDeleted(entity);
  final fields = {
    for (final v in card.newer.values) conflictFieldTitle(l10n, v),
  };
  return l10n.conflictToastOne(entity, fields.join(', '), fields.length);
}

/// Устройство стороны: имя из `info.json`, если папка доступна; это
/// устройство или его прежний id; иначе — конец id.
String conflictDevice(
  AppLocalizations l10n,
  ConflictSide side,
  List<SyncDevice> devices,
) {
  final id = side.nodeId;
  for (final device in devices) {
    if (device.nodeId == id) return deviceTitle(l10n, device);
  }
  if (side.isThisDevice) return l10n.conflictThisDevice;
  if (side.isFormerThisDevice) return l10n.deviceFormerThis;
  return l10n.conflictUnknownDevice(
    id.length > 6 ? id.substring(id.length - 6) : id,
  );
}

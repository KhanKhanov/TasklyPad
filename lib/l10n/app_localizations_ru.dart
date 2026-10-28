// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Планер';

  @override
  String get inbox => 'Входящие';

  @override
  String get inboxEmpty => 'Пока нет задач';

  @override
  String get startupErrorTitle => 'Не удалось открыть данные';

  @override
  String startupSchemaTooNew(int found, int supported) {
    return 'Данные сохранены более новой версией приложения (схема $found, эта версия знает до $supported). Обновите приложение — данные не тронуты.';
  }

  @override
  String startupBadProfile(String name) {
    return 'Имя профиля «$name» не подходит: нужны латинские строчные буквы, цифры и дефис, до 32 символов. Данные не тронуты.';
  }

  @override
  String startupErrorDetails(String error) {
    return 'Данные не изменены. Подробности: $error';
  }

  @override
  String get myProjects => 'Мои проекты';

  @override
  String get favorites => 'Избранное';

  @override
  String get addProject => 'Добавить проект';

  @override
  String get editProject => 'Редактировать проект';

  @override
  String get fieldName => 'Название';

  @override
  String get fieldColor => 'Цвет';

  @override
  String get fieldParent => 'Родительский проект';

  @override
  String get noParent => 'Без родителя';

  @override
  String get fieldFavorite => 'Добавить в избранное';

  @override
  String get addToFavorites => 'Добавить в избранное';

  @override
  String get removeFromFavorites => 'Удалить из избранного';

  @override
  String get actionEdit => 'Редактировать';

  @override
  String get actionDuplicate => 'Дублировать';

  @override
  String get actionArchive => 'Архивировать';

  @override
  String get actionUnarchive => 'Вернуть из архива';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionMoveTo => 'Перенести в…';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionAdd => 'Добавить';

  @override
  String copyOf(String name) {
    return 'Копия $name';
  }

  @override
  String get archiveProjectTitle => 'Архивировать проект?';

  @override
  String archiveProjectBody(String name) {
    return 'Проект «$name» и его подпроекты будут перемещены в архив.';
  }

  @override
  String get deleteProjectTitle => 'Удалить проект?';

  @override
  String deleteProjectBody(String name) {
    return 'Проект «$name» будет удалён вместе со всеми задачами.';
  }

  @override
  String get addSection => 'Добавить раздел';

  @override
  String get sectionNameHint => 'Название раздела';

  @override
  String get archiveSectionTitle => 'Архивировать раздел?';

  @override
  String archiveSectionBody(String name) {
    return 'Раздел «$name» будет перемещён в архив, а его задачи — отмечены выполненными.';
  }

  @override
  String get deleteSectionTitle => 'Удалить раздел?';

  @override
  String deleteSectionBody(String name) {
    return 'Раздел «$name» будет удалён вместе со всеми задачами.';
  }

  @override
  String get moveSectionTitle => 'Перенести раздел';

  @override
  String get projectsActive => 'Активные';

  @override
  String get projectsArchived => 'В архиве';

  @override
  String get noArchivedProjects => 'В архиве нет проектов';

  @override
  String get toggleSidebar => 'Открыть или закрыть боковую панель';

  @override
  String get moreActions => 'Ещё';

  @override
  String get rejectEmptyName => 'Введите название';

  @override
  String get rejectInboxProtected => 'Это нельзя сделать с «Входящими»';

  @override
  String get rejectTooDeep => 'Слишком глубокая вложенность';

  @override
  String get rejectCycle => 'Нельзя вложить в самого себя';

  @override
  String get rejectTooManySections => 'В проекте уже 20 разделов';

  @override
  String get rejectDuplicateName => 'Такое имя уже есть';

  @override
  String get rejectNotFound =>
      'Не найдено — возможно, удалено на другом устройстве';

  @override
  String get colorBerryRed => 'Ягодный';

  @override
  String get colorRed => 'Красный';

  @override
  String get colorOrange => 'Оранжевый';

  @override
  String get colorYellow => 'Жёлтый';

  @override
  String get colorOliveGreen => 'Оливковый';

  @override
  String get colorLimeGreen => 'Салатовый';

  @override
  String get colorGreen => 'Зелёный';

  @override
  String get colorMintGreen => 'Мятный';

  @override
  String get colorTeal => 'Бирюзовый';

  @override
  String get colorSkyBlue => 'Небесно-голубой';

  @override
  String get colorLightBlue => 'Светло-голубой';

  @override
  String get colorBlue => 'Синий';

  @override
  String get colorGrape => 'Виноградный';

  @override
  String get colorViolet => 'Фиолетовый';

  @override
  String get colorLavender => 'Лавандовый';

  @override
  String get colorMagenta => 'Пурпурный';

  @override
  String get colorSalmon => 'Лососевый';

  @override
  String get colorCharcoal => 'Графитовый';

  @override
  String get colorGrey => 'Серый';

  @override
  String get colorTaupe => 'Серо-коричневый';

  @override
  String loadError(String error) {
    return 'Не удалось загрузить данные. Подробности: $error';
  }

  @override
  String get addTask => 'Добавить задачу';

  @override
  String get taskNameHint => 'Название задачи';

  @override
  String get descriptionHint => 'Описание';

  @override
  String get taskCompleted => 'Задача выполнена';

  @override
  String get taskMoved => 'Задача перенесена';

  @override
  String get dueChanged => 'Срок изменён';

  @override
  String get actionUndo => 'Отменить';

  @override
  String get deleteTaskTitle => 'Удалить задачу?';

  @override
  String deleteTaskBody(String name) {
    return 'Задача «$name» будет удалена вместе с подзадачами.';
  }

  @override
  String get viewOptions => 'Отображение';

  @override
  String get completedTasks => 'Выполненные задачи';

  @override
  String get dueToday => 'Сегодня';

  @override
  String get dueTomorrow => 'Завтра';

  @override
  String get dueYesterday => 'Вчера';

  @override
  String get dueWeekend => 'На выходных';

  @override
  String get dueNextWeek => 'Следующая неделя';

  @override
  String get noDue => 'Без срока';

  @override
  String get pickDate => 'Выбрать дату…';

  @override
  String get addTime => 'Добавить время';

  @override
  String get removeTime => 'Убрать время';

  @override
  String get fieldProject => 'Проект';

  @override
  String get fieldDue => 'Срок';

  @override
  String get fieldDeadline => 'Дедлайн';

  @override
  String get fieldPriority => 'Приоритет';

  @override
  String get fieldLabels => 'Метки';

  @override
  String get fieldDuration => 'Длительность';

  @override
  String get noDeadline => 'Без дедлайна';

  @override
  String get noDuration => 'Без длительности';

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String priorityN(int n) {
    return 'Приоритет $n';
  }

  @override
  String get subtasks => 'Подзадачи';

  @override
  String get addSubtask => 'Добавить подзадачу';

  @override
  String get showCompleted => 'Показать выполненные';

  @override
  String get hideCompleted => 'Скрыть выполненные';

  @override
  String get completeTask => 'Выполнить';

  @override
  String get reopenTask => 'Вернуть в работу';

  @override
  String createLabel(String name) {
    return 'Создать метку «$name»';
  }

  @override
  String get labelSearchHint => 'Метка';

  @override
  String get actionDone => 'Готово';

  @override
  String actionFailed(String error) {
    return 'Не удалось выполнить действие. Подробности: $error';
  }

  @override
  String get filtersAndLabels => 'Фильтры и метки';

  @override
  String get labelsHeader => 'Метки';

  @override
  String get addLabel => 'Добавить метку';

  @override
  String get editLabel => 'Изменить метку';

  @override
  String get deleteLabel => 'Удалить метку';

  @override
  String get deleteLabelTitle => 'Удалить метку?';

  @override
  String deleteLabelBody(String name) {
    return 'Метка «$name» будет удалена со всех задач.';
  }

  @override
  String get noLabels => 'Пока нет меток';

  @override
  String get previousTask => 'Предыдущая задача';

  @override
  String get nextTask => 'Следующая задача';

  @override
  String get settings => 'Настройки';

  @override
  String get syncSection => 'Синхронизация';

  @override
  String get themeSection => 'Тема';

  @override
  String get themeAppearance => 'Внешний вид';

  @override
  String get appearanceLight => 'Светлый';

  @override
  String get appearanceDark => 'Тёмный';

  @override
  String get appearanceSystem => 'Системный';

  @override
  String get themeTaskly => 'Taskly';

  @override
  String get syncTheme => 'Синхронизировать тему';

  @override
  String get themeUpdate => 'Обновить';

  @override
  String get syncFolder => 'Папка синхронизации';

  @override
  String get syncFolderNone =>
      'Папка не выбрана — данные есть только на этом устройстве.';

  @override
  String get syncFolderHint =>
      'Выберите общую папку OneDrive, Google Drive или Syncthing: приложение создаст в ней папку planner-sync. На других устройствах выберите ту же папку.';

  @override
  String get chooseFolder => 'Выбрать папку…';

  @override
  String get changeFolder => 'Сменить папку…';

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get syncRunning => 'Синхронизация…';

  @override
  String syncLast(String time) {
    return 'Синхронизировано: $time';
  }

  @override
  String get syncNever => 'Ещё не синхронизировалось';

  @override
  String syncIssues(int count) {
    return 'Пока не прочитано файлов других устройств: $count. Облако могло ещё не докачать их — повторю при следующей синхронизации.';
  }

  @override
  String get syncErrorFormat =>
      'Папку записала более новая версия приложения. Обновите приложение на этом устройстве — в папку ничего не записано.';

  @override
  String get syncErrorBusy =>
      'Синхронизация этих данных уже идёт — повторю позже.';

  @override
  String get syncErrorRetiredUnread =>
      'Папка не сменена: часть правок отмеченных устройств в прежней папке не прочитана. Попробуйте позже.';

  @override
  String get retiredUnreadTitle => 'Не все правки прочитаны';

  @override
  String get retiredUnreadBody =>
      'Часть правок отмеченных устройств в прежней папке не прочитана: облако ещё докачивает файлы, файл повреждён, часы устройства спешат или прежняя папка недоступна. Можно подождать и повторить смену. Если сменить всё равно, непрочитанное в новую папку не попадёт; прежняя папка останется как есть.';

  @override
  String get retiredUnreadAction => 'Сменить всё равно';

  @override
  String get syncErrorFolderMissing =>
      'Папка синхронизации не найдена: её удалили или диск либо облако не подключены. В неё ничего не записано.';

  @override
  String get syncErrorRootMissing =>
      'Выбранная папка не найдена: подключите диск или облако либо выберите другую папку. В неё ничего не записано.';

  @override
  String get recreateFolderAction => 'Создать папку заново';

  @override
  String get recreateFolderTitle => 'Создать папку синхронизации заново?';

  @override
  String get recreateFolderBody =>
      'В выбранной папке будет создана новая папка синхронизации, и это устройство выгрузит в неё все свои данные; остальные устройства подхватят её сами. Если диск или облако просто временно не подключены, подождите и подключите их — иначе появится вторая, отдельная папка.';

  @override
  String get folderRecreated => 'Папка синхронизации подключена заново';

  @override
  String syncErrorOther(String error) {
    return 'Синхронизация не удалась: $error';
  }

  @override
  String get changeFolderTitle => 'Сменить папку синхронизации?';

  @override
  String changeFolderBody(String path) {
    return 'Новая папка: $path. Прежняя папка не изменится. Переключите на новую папку и остальные устройства, которыми пользуетесь, — свои правки они перенесут сами.';
  }

  @override
  String get changeFolderRetiredHint =>
      'Отметьте устройства, которыми больше не пользуетесь: их правки это устройство запишет в новую папку. Устройство, которое ещё переключите, не отмечайте — иначе его новые правки покажутся конфликтом.';

  @override
  String get changeFolderNoDevices =>
      'Устройства прежней папки прочитать не удалось: правки других устройств в новую папку не перенесутся.';

  @override
  String get changeFolderAction => 'Сменить';

  @override
  String get folderConnected => 'Папка подключена';

  @override
  String folderAdopted(int count) {
    return 'Папка подключена. В неё записаны правки устройств, которыми больше не пользуетесь: $count';
  }

  @override
  String folderAdoptedPartial(int adopted, int unreadable) {
    return 'Папка подключена. В неё записаны правки устройств, которыми больше не пользуетесь: $adopted. Прочитаны не все правки устройств: $unreadable — непрочитанное осталось в прежней папке';
  }

  @override
  String folderUnreadable(int count) {
    return 'Папка подключена. Прочитаны не все правки устройств, которыми больше не пользуетесь: $count — непрочитанное осталось в прежней папке';
  }

  @override
  String get recreateFolderRetiredHint =>
      'Отметьте устройства, которыми больше не пользуетесь: их правки, известные этому устройству, будут записаны в новую папку. Имён нет — описания устройств пропали вместе с папкой; ориентируйтесь по времени последней правки. «Это устройство до копирования базы» отметьте, если компьютером, с которого база скопирована, больше не пользуетесь. Устройство, которым ещё пользуетесь, не отмечайте — иначе его новые правки покажутся конфликтом.';

  @override
  String get recreateFolderNoDevices =>
      'Устройства из журнала не прочитаны: правки других устройств в новую папку не попадут.';

  @override
  String folderRecreatedAdopted(int count) {
    return 'Папка синхронизации подключена заново. В неё записаны правки устройств, которыми больше не пользуетесь: $count';
  }

  @override
  String deviceLastEdit(String time, String id) {
    return 'последняя правка $time · …$id';
  }

  @override
  String get devicesHeader => 'Устройства';

  @override
  String get thisDevice => 'это устройство';

  @override
  String get devicesUnread =>
      'Устройства не прочитаны: папка синхронизации недоступна';

  @override
  String get deviceFormerThis => 'Это устройство до копирования базы';

  @override
  String get deviceUnnamed => 'Устройство без описания';

  @override
  String deviceUpdated(String time) {
    return 'выгружало правки $time';
  }

  @override
  String get rebuildTitle => 'Пересобрать базу из журнала';

  @override
  String get rebuildBody =>
      'Данные будут заново собраны из журнала изменений. Журнал не меняется, правки не теряются. Нужно, если данные выглядят неправильно.';

  @override
  String get rebuildAction => 'Пересобрать';

  @override
  String get rebuildDone => 'База пересобрана';

  @override
  String get syncUnsupported =>
      'На этом устройстве выбор папки синхронизации появится позже.';

  @override
  String deviceWithProfile(String name, String profile) {
    return '$name ($profile)';
  }

  @override
  String deviceThis(String name) {
    return '$name — это устройство';
  }

  @override
  String get conflicts => 'Конфликты';

  @override
  String get conflictsHint =>
      'Одно и то же изменили на двух устройствах. Пока вы не выбрали, действует более поздняя правка.';

  @override
  String get conflictsEmpty => 'Конфликтов нет';

  @override
  String get conflictKeepThis => 'Оставить этот вариант';

  @override
  String get conflictKeepCurrent => 'Оставить текущее';

  @override
  String get conflictKeepDeleted => 'Оставить удалённым';

  @override
  String get conflictRestore => 'Восстановить';

  @override
  String get conflictActive => 'Действует сейчас';

  @override
  String get conflictCurrent => 'Сейчас';

  @override
  String conflictUnknownDevice(String id) {
    return 'Устройство …$id';
  }

  @override
  String conflictEntityTask(String title) {
    return 'Задача «$title»';
  }

  @override
  String conflictEntityProject(String title) {
    return 'Проект «$title»';
  }

  @override
  String conflictEntitySection(String title) {
    return 'Раздел «$title»';
  }

  @override
  String conflictEntityLabel(String title) {
    return 'Метка «$title»';
  }

  @override
  String conflictEntityTaskLabel(String label, String task) {
    return 'Метка «$label» у задачи «$task»';
  }

  @override
  String get conflictEntitySettings => 'Настройки';

  @override
  String conflictEntityOther(String title) {
    return 'Запись «$title»';
  }

  @override
  String get conflictUntitled => 'без названия';

  @override
  String get conflictToastTitle => 'Конфликт синхронизации';

  @override
  String conflictToastOne(String entity, String field, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Конфликт: $entity, поля $field',
      one: 'Конфликт: $entity, поле $field',
    );
    return '$_temp0';
  }

  @override
  String conflictToastDeleted(String entity) {
    return 'Конфликт удаления: $entity';
  }

  @override
  String conflictToastMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нового конфликта синхронизации',
      many: '$count новых конфликтов синхронизации',
      few: '$count новых конфликта синхронизации',
      one: '$count новый конфликт синхронизации',
    );
    return '$_temp0';
  }

  @override
  String get conflictOpen => 'Открыть';

  @override
  String get conflictRestoredHidden =>
      'Восстановлено, но не видно: удалены его проект, раздел или родительская задача';

  @override
  String get fieldDescription => 'Описание';

  @override
  String get fieldSection => 'Раздел';

  @override
  String get fieldParentTask => 'Родительская задача';

  @override
  String get fieldCompleted => 'Выполнение';

  @override
  String get fieldInFavorites => 'Избранное';

  @override
  String get fieldArchived => 'Архив';

  @override
  String get fieldViewStyle => 'Раскладка';

  @override
  String get valueCompleted => 'Выполнена';

  @override
  String get valueNotCompleted => 'Не выполнена';

  @override
  String get valueInFavorites => 'В избранном';

  @override
  String get valueNotInFavorites => 'Не в избранном';

  @override
  String get valueArchived => 'В архиве';

  @override
  String get valueNotArchived => 'Не в архиве';

  @override
  String get valueDeleted => 'Удалено';

  @override
  String get valueRestored => 'Восстановлено';

  @override
  String get valueLabelRemoved => 'Метка снята';

  @override
  String get valueLabelAdded => 'Метка поставлена';

  @override
  String get valueEdited => 'Изменено';

  @override
  String get valueEmpty => '(пусто)';

  @override
  String get valueMissing => 'не найдено на этом устройстве';

  @override
  String valueDeletedRef(String name) {
    return '$name (удалено)';
  }

  @override
  String get viewList => 'Список';

  @override
  String get viewBoard => 'Доска';

  @override
  String get viewCalendar => 'Календарь';

  @override
  String get noSection => 'Без раздела';

  @override
  String get conflictThisDevice => 'Это устройство';

  @override
  String get conflictDeleteAgainTitle => 'Удалить снова?';

  @override
  String conflictDeleteAgainBody(String entity) {
    return 'Сейчас это не удалено. «$entity» будет удалено вместе со всем, что внутри.';
  }
}

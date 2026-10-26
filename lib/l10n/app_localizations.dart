import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Название приложения в заголовке окна
  ///
  /// In ru, this message translates to:
  /// **'Планер'**
  String get appTitle;

  /// Проект по умолчанию, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Входящие'**
  String get inbox;

  /// Заглушка пустого списка во Входящих
  ///
  /// In ru, this message translates to:
  /// **'Пока нет задач'**
  String get inboxEmpty;

  /// Заголовок экрана, если база не открылась при запуске
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть данные'**
  String get startupErrorTitle;

  /// База создана более новой версией приложения
  ///
  /// In ru, this message translates to:
  /// **'Данные сохранены более новой версией приложения (схема {found}, эта версия знает до {supported}). Обновите приложение — данные не тронуты.'**
  String startupSchemaTooNew(int found, int supported);

  /// Прочая ошибка открытия базы при запуске
  ///
  /// In ru, this message translates to:
  /// **'Данные не изменены. Подробности: {error}'**
  String startupErrorDetails(String error);

  /// Группа проектов в сайдбаре и экран проектов, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Мои проекты'**
  String get myProjects;

  /// Группа избранного в сайдбаре
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favorites;

  /// Кнопка и заголовок диалога
  ///
  /// In ru, this message translates to:
  /// **'Добавить проект'**
  String get addProject;

  /// Заголовок диалога правки проекта
  ///
  /// In ru, this message translates to:
  /// **'Редактировать проект'**
  String get editProject;

  /// Поле названия проекта
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get fieldName;

  /// Поле цвета проекта
  ///
  /// In ru, this message translates to:
  /// **'Цвет'**
  String get fieldColor;

  /// Поле родителя проекта
  ///
  /// In ru, this message translates to:
  /// **'Родительский проект'**
  String get fieldParent;

  /// Значение «нет родителя»
  ///
  /// In ru, this message translates to:
  /// **'Без родителя'**
  String get noParent;

  /// Переключатель в диалоге проекта
  ///
  /// In ru, this message translates to:
  /// **'Добавить в избранное'**
  String get fieldFavorite;

  /// Пункт меню проекта
  ///
  /// In ru, this message translates to:
  /// **'Добавить в избранное'**
  String get addToFavorites;

  /// Пункт меню проекта
  ///
  /// In ru, this message translates to:
  /// **'Удалить из избранного'**
  String get removeFromFavorites;

  /// Пункт меню
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get actionEdit;

  /// Пункт меню
  ///
  /// In ru, this message translates to:
  /// **'Дублировать'**
  String get actionDuplicate;

  /// Пункт меню и кнопка подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Архивировать'**
  String get actionArchive;

  /// Пункт меню архивного проекта
  ///
  /// In ru, this message translates to:
  /// **'Вернуть из архива'**
  String get actionUnarchive;

  /// Пункт меню и кнопка подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get actionDelete;

  /// Пункт меню раздела
  ///
  /// In ru, this message translates to:
  /// **'Перенести в…'**
  String get actionMoveTo;

  /// Кнопка
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get actionCancel;

  /// Кнопка
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get actionSave;

  /// Кнопка
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get actionAdd;

  /// Имя дубликата проекта или раздела
  ///
  /// In ru, this message translates to:
  /// **'Копия {name}'**
  String copyOf(String name);

  /// Заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Архивировать проект?'**
  String get archiveProjectTitle;

  /// Текст подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Проект «{name}» и его подпроекты будут перемещены в архив.'**
  String archiveProjectBody(String name);

  /// Заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Удалить проект?'**
  String get deleteProjectTitle;

  /// Текст подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Проект «{name}» будет удалён вместе со всеми задачами.'**
  String deleteProjectBody(String name);

  /// Кнопка, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Добавить раздел'**
  String get addSection;

  /// Подсказка в поле раздела
  ///
  /// In ru, this message translates to:
  /// **'Название раздела'**
  String get sectionNameHint;

  /// Заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Архивировать раздел?'**
  String get archiveSectionTitle;

  /// Текст подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Раздел «{name}» будет перемещён в архив, а его задачи — отмечены выполненными.'**
  String archiveSectionBody(String name);

  /// Заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Удалить раздел?'**
  String get deleteSectionTitle;

  /// Текст подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Раздел «{name}» будет удалён вместе со всеми задачами.'**
  String deleteSectionBody(String name);

  /// Заголовок выбора проекта
  ///
  /// In ru, this message translates to:
  /// **'Перенести раздел'**
  String get moveSectionTitle;

  /// Вкладка экрана проектов
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get projectsActive;

  /// Вкладка экрана проектов
  ///
  /// In ru, this message translates to:
  /// **'В архиве'**
  String get projectsArchived;

  /// Пустой архив
  ///
  /// In ru, this message translates to:
  /// **'В архиве нет проектов'**
  String get noArchivedProjects;

  /// Подсказка кнопки
  ///
  /// In ru, this message translates to:
  /// **'Открыть или закрыть боковую панель'**
  String get toggleSidebar;

  /// Подсказка кнопки меню
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get moreActions;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get rejectEmptyName;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Это нельзя сделать с «Входящими»'**
  String get rejectInboxProtected;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Слишком глубокая вложенность'**
  String get rejectTooDeep;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Нельзя вложить в самого себя'**
  String get rejectCycle;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'В проекте уже 20 разделов'**
  String get rejectTooManySections;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Такое имя уже есть'**
  String get rejectDuplicateName;

  /// Действие отклонено
  ///
  /// In ru, this message translates to:
  /// **'Не найдено — возможно, удалено на другом устройстве'**
  String get rejectNotFound;

  /// Цвет палитры (русские названия — наш перевод, О-4)
  ///
  /// In ru, this message translates to:
  /// **'Ягодный'**
  String get colorBerryRed;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Красный'**
  String get colorRed;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Оранжевый'**
  String get colorOrange;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Жёлтый'**
  String get colorYellow;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Оливковый'**
  String get colorOliveGreen;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Салатовый'**
  String get colorLimeGreen;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Зелёный'**
  String get colorGreen;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Мятный'**
  String get colorMintGreen;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Бирюзовый'**
  String get colorTeal;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Небесно-голубой'**
  String get colorSkyBlue;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Светло-голубой'**
  String get colorLightBlue;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Синий'**
  String get colorBlue;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Виноградный'**
  String get colorGrape;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Фиолетовый'**
  String get colorViolet;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Лавандовый'**
  String get colorLavender;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Пурпурный'**
  String get colorMagenta;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Лососевый'**
  String get colorSalmon;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Графитовый'**
  String get colorCharcoal;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Серый'**
  String get colorGrey;

  /// Цвет палитры
  ///
  /// In ru, this message translates to:
  /// **'Серо-коричневый'**
  String get colorTaupe;

  /// Ошибка чтения снимка данных
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные. Подробности: {error}'**
  String loadError(String error);

  /// Кнопка и редактор, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Добавить задачу'**
  String get addTask;

  /// Подсказка поля названия
  ///
  /// In ru, this message translates to:
  /// **'Название задачи'**
  String get taskNameHint;

  /// Подсказка поля описания
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get descriptionHint;

  /// Тост после завершения
  ///
  /// In ru, this message translates to:
  /// **'Задача выполнена'**
  String get taskCompleted;

  /// Тост после переноса
  ///
  /// In ru, this message translates to:
  /// **'Задача перенесена'**
  String get taskMoved;

  /// Тост после смены срока
  ///
  /// In ru, this message translates to:
  /// **'Срок изменён'**
  String get dueChanged;

  /// Кнопка в тосте
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get actionUndo;

  /// Заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Удалить задачу?'**
  String get deleteTaskTitle;

  /// Текст подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Задача «{name}» будет удалена вместе с подзадачами.'**
  String deleteTaskBody(String name);

  /// Кнопка настроек вида, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Просмотр'**
  String get viewOptions;

  /// Переключатель в «Просмотр»
  ///
  /// In ru, this message translates to:
  /// **'Выполненные задачи'**
  String get completedTasks;

  /// Срок
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dueToday;

  /// Срок
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get dueTomorrow;

  /// Срок
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get dueYesterday;

  /// Быстрый вариант срока
  ///
  /// In ru, this message translates to:
  /// **'На выходных'**
  String get dueWeekend;

  /// Быстрый вариант срока
  ///
  /// In ru, this message translates to:
  /// **'Следующая неделя'**
  String get dueNextWeek;

  /// Убрать срок
  ///
  /// In ru, this message translates to:
  /// **'Без срока'**
  String get noDue;

  /// Пункт выбора даты
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату…'**
  String get pickDate;

  /// Пункт выбора времени
  ///
  /// In ru, this message translates to:
  /// **'Добавить время'**
  String get addTime;

  /// Пункт выбора времени
  ///
  /// In ru, this message translates to:
  /// **'Убрать время'**
  String get removeTime;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Проект'**
  String get fieldProject;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get fieldDue;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн'**
  String get fieldDeadline;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Приоритет'**
  String get fieldPriority;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Метки'**
  String get fieldLabels;

  /// Поле панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get fieldDuration;

  /// Убрать дедлайн
  ///
  /// In ru, this message translates to:
  /// **'Без дедлайна'**
  String get noDeadline;

  /// Убрать длительность
  ///
  /// In ru, this message translates to:
  /// **'Без длительности'**
  String get noDuration;

  /// Длительность в минутах
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutes(int minutes);

  /// Приоритет 1–4
  ///
  /// In ru, this message translates to:
  /// **'Приоритет {n}'**
  String priorityN(int n);

  /// Раздел панели задачи
  ///
  /// In ru, this message translates to:
  /// **'Подзадачи'**
  String get subtasks;

  /// Кнопка, как в Todoist
  ///
  /// In ru, this message translates to:
  /// **'Добавить подзадачу'**
  String get addSubtask;

  /// Переключатель подзадач
  ///
  /// In ru, this message translates to:
  /// **'Показать выполненные'**
  String get showCompleted;

  /// Переключатель подзадач
  ///
  /// In ru, this message translates to:
  /// **'Скрыть выполненные'**
  String get hideCompleted;

  /// Подсказка кружка задачи
  ///
  /// In ru, this message translates to:
  /// **'Выполнить'**
  String get completeTask;

  /// Подсказка кружка выполненной задачи
  ///
  /// In ru, this message translates to:
  /// **'Вернуть в работу'**
  String get reopenTask;

  /// Пункт выбора меток
  ///
  /// In ru, this message translates to:
  /// **'Создать метку «{name}»'**
  String createLabel(String name);

  /// Подсказка поля поиска метки
  ///
  /// In ru, this message translates to:
  /// **'Метка'**
  String get labelSearchHint;

  /// Кнопка закрытия выбора
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get actionDone;

  /// Неожиданная ошибка записи (не отказ правилами)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие. Подробности: {error}'**
  String actionFailed(String error);

  /// Пункт сайдбара и страница фильтров и меток
  ///
  /// In ru, this message translates to:
  /// **'Фильтры и метки'**
  String get filtersAndLabels;

  /// Заголовок раздела меток на странице «Фильтры и метки»
  ///
  /// In ru, this message translates to:
  /// **'Метки'**
  String get labelsHeader;

  /// Кнопка и заголовок диалога новой метки
  ///
  /// In ru, this message translates to:
  /// **'Добавить метку'**
  String get addLabel;

  /// Пункт меню и заголовок диалога правки метки
  ///
  /// In ru, this message translates to:
  /// **'Изменить метку'**
  String get editLabel;

  /// Пункт меню метки
  ///
  /// In ru, this message translates to:
  /// **'Удалить метку'**
  String get deleteLabel;

  /// Заголовок подтверждения удаления метки
  ///
  /// In ru, this message translates to:
  /// **'Удалить метку?'**
  String get deleteLabelTitle;

  /// Текст подтверждения удаления метки
  ///
  /// In ru, this message translates to:
  /// **'Метка «{name}» будет удалена со всех задач.'**
  String deleteLabelBody(String name);

  /// Пустой список меток
  ///
  /// In ru, this message translates to:
  /// **'Пока нет меток'**
  String get noLabels;

  /// Кнопка «вверх» в панели задачи (K)
  ///
  /// In ru, this message translates to:
  /// **'Предыдущая задача'**
  String get previousTask;

  /// Кнопка «вниз» в панели задачи (J)
  ///
  /// In ru, this message translates to:
  /// **'Следующая задача'**
  String get nextTask;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

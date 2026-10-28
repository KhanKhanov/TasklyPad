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

  /// Неверное имя профиля в аргументе --profile
  ///
  /// In ru, this message translates to:
  /// **'Имя профиля «{name}» не подходит: нужны латинские строчные буквы, цифры и дефис, до 32 символов. Данные не тронуты.'**
  String startupBadProfile(String name);

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
  /// **'Отображение'**
  String get viewOptions;

  /// Переключатель в «Отображение»
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

  /// Пункт меню и заголовок экрана настроек
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// Раздел настроек
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get syncSection;

  /// Раздел настроек и подпись поля в конфликте
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get themeSection;

  /// Светлый, тёмный или как в системе (Todoist: Appearance)
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get themeAppearance;

  /// Внешний вид
  ///
  /// In ru, this message translates to:
  /// **'Светлый'**
  String get appearanceLight;

  /// Внешний вид
  ///
  /// In ru, this message translates to:
  /// **'Тёмный'**
  String get appearanceDark;

  /// Внешний вид как в системе (Todoist: System)
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get appearanceSystem;

  /// Название темы
  ///
  /// In ru, this message translates to:
  /// **'Taskly'**
  String get themeTaskly;

  /// Переключатель, как в Todoist (Sync theme)
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать тему'**
  String get syncTheme;

  /// Кнопка сохранения темы на компьютере (Todoist: Update)
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get themeUpdate;

  /// Подпись выбранной папки
  ///
  /// In ru, this message translates to:
  /// **'Папка синхронизации'**
  String get syncFolder;

  /// Синхронизация не настроена
  ///
  /// In ru, this message translates to:
  /// **'Папка не выбрана — данные есть только на этом устройстве.'**
  String get syncFolderNone;

  /// Пояснение к выбору папки
  ///
  /// In ru, this message translates to:
  /// **'Выберите общую папку OneDrive, Google Drive или Syncthing: приложение создаст в ней папку planner-sync. На других устройствах выберите ту же папку.'**
  String get syncFolderHint;

  /// Кнопка выбора папки
  ///
  /// In ru, this message translates to:
  /// **'Выбрать папку…'**
  String get chooseFolder;

  /// Кнопка смены папки
  ///
  /// In ru, this message translates to:
  /// **'Сменить папку…'**
  String get changeFolder;

  /// Кнопка синхронизации
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать'**
  String get syncNow;

  /// Идёт проход
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация…'**
  String get syncRunning;

  /// Время последней удачной синхронизации
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано: {time}'**
  String syncLast(String time);

  /// Синхронизаций ещё не было
  ///
  /// In ru, this message translates to:
  /// **'Ещё не синхронизировалось'**
  String get syncNever;

  /// Файлы, не прочитанные в последнем проходе
  ///
  /// In ru, this message translates to:
  /// **'Пока не прочитано файлов других устройств: {count}. Облако могло ещё не докачать их — повторю при следующей синхронизации.'**
  String syncIssues(int count);

  /// SyncFormatException
  ///
  /// In ru, this message translates to:
  /// **'Папку записала более новая версия приложения. Обновите приложение на этом устройстве — в папку ничего не записано.'**
  String get syncErrorFormat;

  /// Аренда занята
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация этих данных уже идёт — повторю позже.'**
  String get syncErrorBusy;

  /// Смена папки не начата: чанки отмеченных устройств не прочитаны, пользователь отказался менять всё равно
  ///
  /// In ru, this message translates to:
  /// **'Папка не сменена: часть правок отмеченных устройств в прежней папке не прочитана. Попробуйте позже.'**
  String get syncErrorRetiredUnread;

  /// Смена папки: чанки отмеченных устройств не прочитаны
  ///
  /// In ru, this message translates to:
  /// **'Не все правки прочитаны'**
  String get retiredUnreadTitle;

  /// Пояснение: подождать или сменить папку всё равно
  ///
  /// In ru, this message translates to:
  /// **'Часть правок отмеченных устройств в прежней папке не прочитана: облако ещё докачивает файлы, файл повреждён, часы устройства спешат или прежняя папка недоступна. Можно подождать и повторить смену. Если сменить всё равно, непрочитанное в новую папку не попадёт; прежняя папка останется как есть.'**
  String get retiredUnreadBody;

  /// Сменить папку, не дочитав правки отмеченных устройств
  ///
  /// In ru, this message translates to:
  /// **'Сменить всё равно'**
  String get retiredUnreadAction;

  /// Проход не нашёл папку синхронизации, известную этому устройству (SYNC_DESIGN «Транспорт A»)
  ///
  /// In ru, this message translates to:
  /// **'Папка синхронизации не найдена: её удалили или диск либо облако не подключены. В неё ничего не записано.'**
  String get syncErrorFolderMissing;

  /// Нет самой выбранной папки (корня): её не создаём
  ///
  /// In ru, this message translates to:
  /// **'Выбранная папка не найдена: подключите диск или облако либо выберите другую папку. В неё ничего не записано.'**
  String get syncErrorRootMissing;

  /// Кнопка под ошибкой «папка не найдена»
  ///
  /// In ru, this message translates to:
  /// **'Создать папку заново'**
  String get recreateFolderAction;

  /// Подтверждение пересоздания пропавшей папки
  ///
  /// In ru, this message translates to:
  /// **'Создать папку синхронизации заново?'**
  String get recreateFolderTitle;

  /// Пояснение: пересоздавать, только если папку удалили намеренно
  ///
  /// In ru, this message translates to:
  /// **'В выбранной папке будет создана новая папка синхронизации, и это устройство выгрузит в неё все свои данные; остальные устройства подхватят её сами. Если диск или облако просто временно не подключены, подождите и подключите их — иначе появится вторая, отдельная папка.'**
  String get recreateFolderBody;

  /// Тост после пересоздания папки
  ///
  /// In ru, this message translates to:
  /// **'Папка синхронизации подключена заново'**
  String get folderRecreated;

  /// Прочие ошибки прохода
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация не удалась: {error}'**
  String syncErrorOther(String error);

  /// Подтверждение смены папки
  ///
  /// In ru, this message translates to:
  /// **'Сменить папку синхронизации?'**
  String get changeFolderTitle;

  /// Пояснение к смене папки
  ///
  /// In ru, this message translates to:
  /// **'Новая папка: {path}. Прежняя папка не изменится. Переключите на новую папку и остальные устройства, которыми пользуетесь, — свои правки они перенесут сами.'**
  String changeFolderBody(String path);

  /// Пояснение к списку устройств в диалоге смены папки
  ///
  /// In ru, this message translates to:
  /// **'Отметьте устройства, которыми больше не пользуетесь: их правки это устройство запишет в новую папку. Устройство, которое ещё переключите, не отмечайте — иначе его новые правки покажутся конфликтом.'**
  String get changeFolderRetiredHint;

  /// Диалог смены папки: прежняя папка недоступна
  ///
  /// In ru, this message translates to:
  /// **'Устройства прежней папки прочитать не удалось: правки других устройств в новую папку не перенесутся.'**
  String get changeFolderNoDevices;

  /// Кнопка подтверждения смены папки
  ///
  /// In ru, this message translates to:
  /// **'Сменить'**
  String get changeFolderAction;

  /// Тост после выбора папки
  ///
  /// In ru, this message translates to:
  /// **'Папка подключена'**
  String get folderConnected;

  /// Тост после смены папки с переизданием
  ///
  /// In ru, this message translates to:
  /// **'Папка подключена. В неё записаны правки устройств, которыми больше не пользуетесь: {count}'**
  String folderAdopted(int count);

  /// Тост после смены папки «всё равно»: у отмеченных устройств есть непрочитанные чанки
  ///
  /// In ru, this message translates to:
  /// **'Папка подключена. В неё записаны правки устройств, которыми больше не пользуетесь: {adopted}. Прочитаны не все правки устройств: {unreadable} — непрочитанное осталось в прежней папке'**
  String folderAdoptedPartial(int adopted, int unreadable);

  /// Тост после смены папки «всё равно»: переиздавать нечего, но у отмеченных устройств есть непрочитанные чанки
  ///
  /// In ru, this message translates to:
  /// **'Папка подключена. Прочитаны не все правки устройств, которыми больше не пользуетесь: {count} — непрочитанное осталось в прежней папке'**
  String folderUnreadable(int count);

  /// Пояснение к списку устройств из журнала в диалоге «Создать папку заново»
  ///
  /// In ru, this message translates to:
  /// **'Отметьте устройства, которыми больше не пользуетесь: их правки, известные этому устройству, будут записаны в новую папку. Имён нет — описания устройств пропали вместе с папкой; ориентируйтесь по времени последней правки. «Это устройство до копирования базы» отметьте, если компьютером, с которого база скопирована, больше не пользуетесь. Устройство, которым ещё пользуетесь, не отмечайте — иначе его новые правки покажутся конфликтом.'**
  String get recreateFolderRetiredHint;

  /// Журнал не прочитан в диалоге «Создать папку заново»
  ///
  /// In ru, this message translates to:
  /// **'Устройства из журнала не прочитаны: правки других устройств в новую папку не попадут.'**
  String get recreateFolderNoDevices;

  /// Тост после пересоздания папки с переизданием
  ///
  /// In ru, this message translates to:
  /// **'Папка синхронизации подключена заново. В неё записаны правки устройств, которыми больше не пользуетесь: {count}'**
  String folderRecreatedAdopted(int count);

  /// Устройство из журнала: время последней правки и конец id
  ///
  /// In ru, this message translates to:
  /// **'последняя правка {time} · …{id}'**
  String deviceLastEdit(String time, String id);

  /// Список узлов в папке
  ///
  /// In ru, this message translates to:
  /// **'Устройства'**
  String get devicesHeader;

  /// Пометка своего узла
  ///
  /// In ru, this message translates to:
  /// **'это устройство'**
  String get thisDevice;

  /// Список устройств не прочитан — вместо устаревшего списка
  ///
  /// In ru, this message translates to:
  /// **'Устройства не прочитаны: папка синхронизации недоступна'**
  String get devicesUnread;

  /// Прежний id этого устройства в списке из журнала (база скопирована)
  ///
  /// In ru, this message translates to:
  /// **'Это устройство до копирования базы'**
  String get deviceFormerThis;

  /// Узел без info.json
  ///
  /// In ru, this message translates to:
  /// **'Устройство без описания'**
  String get deviceUnnamed;

  /// Время из info.json
  ///
  /// In ru, this message translates to:
  /// **'выгружало правки {time}'**
  String deviceUpdated(String time);

  /// Пункт и заголовок подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Пересобрать базу из журнала'**
  String get rebuildTitle;

  /// Пояснение к пересборке
  ///
  /// In ru, this message translates to:
  /// **'Данные будут заново собраны из журнала изменений. Журнал не меняется, правки не теряются. Нужно, если данные выглядят неправильно.'**
  String get rebuildBody;

  /// Кнопка подтверждения пересборки
  ///
  /// In ru, this message translates to:
  /// **'Пересобрать'**
  String get rebuildAction;

  /// Тост после пересборки
  ///
  /// In ru, this message translates to:
  /// **'База пересобрана'**
  String get rebuildDone;

  /// Платформа без выбора папки (Android до SAF)
  ///
  /// In ru, this message translates to:
  /// **'На этом устройстве выбор папки синхронизации появится позже.'**
  String get syncUnsupported;

  /// Устройство с профилем данных
  ///
  /// In ru, this message translates to:
  /// **'{name} ({profile})'**
  String deviceWithProfile(String name, String profile);

  /// Своё устройство в списке
  ///
  /// In ru, this message translates to:
  /// **'{name} — это устройство'**
  String deviceThis(String name);

  /// Экран и пункт сайдбара «Конфликты»
  ///
  /// In ru, this message translates to:
  /// **'Конфликты'**
  String get conflicts;

  /// Пояснение на экране «Конфликты»
  ///
  /// In ru, this message translates to:
  /// **'Одно и то же изменили на двух устройствах. Пока вы не выбрали, действует более поздняя правка.'**
  String get conflictsHint;

  /// Пустой экран «Конфликты»
  ///
  /// In ru, this message translates to:
  /// **'Конфликтов нет'**
  String get conflictsEmpty;

  /// Кнопка стороны конфликта
  ///
  /// In ru, this message translates to:
  /// **'Оставить этот вариант'**
  String get conflictKeepThis;

  /// Кнопка: оставить действующие значения
  ///
  /// In ru, this message translates to:
  /// **'Оставить текущее'**
  String get conflictKeepCurrent;

  /// Кнопка стороны удаления
  ///
  /// In ru, this message translates to:
  /// **'Оставить удалённым'**
  String get conflictKeepDeleted;

  /// Кнопка стороны правки в конфликте удаления
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get conflictRestore;

  /// Отметка стороны, значения которой действуют
  ///
  /// In ru, this message translates to:
  /// **'Действует сейчас'**
  String get conflictActive;

  /// Заголовок действующих значений, если поле правили после конфликта
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get conflictCurrent;

  /// Устройство без имени: конец id
  ///
  /// In ru, this message translates to:
  /// **'Устройство …{id}'**
  String conflictUnknownDevice(String id);

  /// Заголовок карточки
  ///
  /// In ru, this message translates to:
  /// **'Задача «{title}»'**
  String conflictEntityTask(String title);

  /// Заголовок карточки
  ///
  /// In ru, this message translates to:
  /// **'Проект «{title}»'**
  String conflictEntityProject(String title);

  /// Заголовок карточки
  ///
  /// In ru, this message translates to:
  /// **'Раздел «{title}»'**
  String conflictEntitySection(String title);

  /// Заголовок карточки
  ///
  /// In ru, this message translates to:
  /// **'Метка «{title}»'**
  String conflictEntityLabel(String title);

  /// Заголовок карточки метки задачи
  ///
  /// In ru, this message translates to:
  /// **'Метка «{label}» у задачи «{task}»'**
  String conflictEntityTaskLabel(String label, String task);

  /// Заголовок карточки конфликта настроек
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get conflictEntitySettings;

  /// Заголовок карточки незнакомой сущности
  ///
  /// In ru, this message translates to:
  /// **'Запись «{title}»'**
  String conflictEntityOther(String title);

  /// Название пустое или неизвестно
  ///
  /// In ru, this message translates to:
  /// **'без названия'**
  String get conflictUntitled;

  /// Заголовок уведомления ОС
  ///
  /// In ru, this message translates to:
  /// **'Конфликт синхронизации'**
  String get conflictToastTitle;

  /// Уведомление об одном конфликте правки
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Конфликт: {entity}, поле {field}} other{Конфликт: {entity}, поля {field}}}'**
  String conflictToastOne(String entity, String field, int count);

  /// Уведомление об одном конфликте удаления
  ///
  /// In ru, this message translates to:
  /// **'Конфликт удаления: {entity}'**
  String conflictToastDeleted(String entity);

  /// Уведомление о нескольких конфликтах
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} новый конфликт синхронизации} few{{count} новых конфликта синхронизации} many{{count} новых конфликтов синхронизации} other{{count} нового конфликта синхронизации}}'**
  String conflictToastMany(int count);

  /// Кнопка тоста: перейти к «Конфликтам»
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get conflictOpen;

  /// Тост после «Восстановить», если элемент скрыт каскадом
  ///
  /// In ru, this message translates to:
  /// **'Восстановлено, но не видно: удалены его проект, раздел или родительская задача'**
  String get conflictRestoredHidden;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get fieldDescription;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Раздел'**
  String get fieldSection;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Родительская задача'**
  String get fieldParentTask;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Выполнение'**
  String get fieldCompleted;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get fieldInFavorites;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Архив'**
  String get fieldArchived;

  /// Подпись поля
  ///
  /// In ru, this message translates to:
  /// **'Раскладка'**
  String get fieldViewStyle;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'Выполнена'**
  String get valueCompleted;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'Не выполнена'**
  String get valueNotCompleted;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'В избранном'**
  String get valueInFavorites;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'Не в избранном'**
  String get valueNotInFavorites;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'В архиве'**
  String get valueArchived;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'Не в архиве'**
  String get valueNotArchived;

  /// Сторона удаления
  ///
  /// In ru, this message translates to:
  /// **'Удалено'**
  String get valueDeleted;

  /// Сторона восстановления
  ///
  /// In ru, this message translates to:
  /// **'Восстановлено'**
  String get valueRestored;

  /// Сторона снятия метки
  ///
  /// In ru, this message translates to:
  /// **'Метка снята'**
  String get valueLabelRemoved;

  /// Сторона установки метки
  ///
  /// In ru, this message translates to:
  /// **'Метка поставлена'**
  String get valueLabelAdded;

  /// Сторона правки без показываемых полей
  ///
  /// In ru, this message translates to:
  /// **'Изменено'**
  String get valueEdited;

  /// Пустое значение
  ///
  /// In ru, this message translates to:
  /// **'(пусто)'**
  String get valueEmpty;

  /// Ссылка на сущность, которой нет
  ///
  /// In ru, this message translates to:
  /// **'не найдено на этом устройстве'**
  String get valueMissing;

  /// Ссылка на удалённую сущность
  ///
  /// In ru, this message translates to:
  /// **'{name} (удалено)'**
  String valueDeletedRef(String name);

  /// Вид проекта
  ///
  /// In ru, this message translates to:
  /// **'Список'**
  String get viewList;

  /// Вид проекта
  ///
  /// In ru, this message translates to:
  /// **'Доска'**
  String get viewBoard;

  /// Вид проекта
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get viewCalendar;

  /// Значение поля
  ///
  /// In ru, this message translates to:
  /// **'Без раздела'**
  String get noSection;

  /// Сторона конфликта с этого устройства, имя которого неизвестно (нет папки)
  ///
  /// In ru, this message translates to:
  /// **'Это устройство'**
  String get conflictThisDevice;

  /// Подтверждение «Оставить удалённым», когда удаление сейчас не действует
  ///
  /// In ru, this message translates to:
  /// **'Удалить снова?'**
  String get conflictDeleteAgainTitle;

  /// Текст подтверждения повторного удаления
  ///
  /// In ru, this message translates to:
  /// **'Сейчас это не удалено. «{entity}» будет удалено вместе со всем, что внутри.'**
  String conflictDeleteAgainBody(String entity);
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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Planner';

  @override
  String get inbox => 'Inbox';

  @override
  String get inboxEmpty => 'No tasks yet';

  @override
  String get startupErrorTitle => 'Couldn\'t open your data';

  @override
  String startupSchemaTooNew(int found, int supported) {
    return 'Your data was saved by a newer version of the app (schema $found, this version supports up to $supported). Update the app — your data is untouched.';
  }

  @override
  String startupErrorDetails(String error) {
    return 'Your data was not changed. Details: $error';
  }

  @override
  String get myProjects => 'My Projects';

  @override
  String get favorites => 'Favorites';

  @override
  String get addProject => 'Add project';

  @override
  String get editProject => 'Edit project';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldColor => 'Color';

  @override
  String get fieldParent => 'Parent project';

  @override
  String get noParent => 'No parent';

  @override
  String get fieldFavorite => 'Add to favorites';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionUnarchive => 'Unarchive';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionMoveTo => 'Move to…';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionAdd => 'Add';

  @override
  String copyOf(String name) {
    return 'Copy of $name';
  }

  @override
  String get archiveProjectTitle => 'Archive project?';

  @override
  String archiveProjectBody(String name) {
    return '\"$name\" and its sub-projects will be archived.';
  }

  @override
  String get deleteProjectTitle => 'Delete project?';

  @override
  String deleteProjectBody(String name) {
    return '\"$name\" and all its tasks will be deleted.';
  }

  @override
  String get addSection => 'Add section';

  @override
  String get sectionNameHint => 'Name this section';

  @override
  String get archiveSectionTitle => 'Archive section?';

  @override
  String archiveSectionBody(String name) {
    return '\"$name\" will be archived and its tasks marked complete.';
  }

  @override
  String get deleteSectionTitle => 'Delete section?';

  @override
  String deleteSectionBody(String name) {
    return '\"$name\" and all its tasks will be deleted.';
  }

  @override
  String get moveSectionTitle => 'Move section';

  @override
  String get projectsActive => 'Active';

  @override
  String get projectsArchived => 'Archived';

  @override
  String get noArchivedProjects => 'No archived projects';

  @override
  String get toggleSidebar => 'Open or close sidebar';

  @override
  String get moreActions => 'More actions';

  @override
  String get rejectEmptyName => 'Enter a name';

  @override
  String get rejectInboxProtected => 'This can\'t be done with the Inbox';

  @override
  String get rejectTooDeep => 'Too many nesting levels';

  @override
  String get rejectCycle => 'Can\'t nest inside itself';

  @override
  String get rejectTooManySections => 'This project already has 20 sections';

  @override
  String get rejectDuplicateName => 'This name is already taken';

  @override
  String get rejectNotFound =>
      'Not found — it may have been deleted on another device';

  @override
  String get colorBerryRed => 'Berry Red';

  @override
  String get colorRed => 'Red';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorOliveGreen => 'Olive Green';

  @override
  String get colorLimeGreen => 'Lime Green';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorMintGreen => 'Mint Green';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorSkyBlue => 'Sky Blue';

  @override
  String get colorLightBlue => 'Light Blue';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGrape => 'Grape';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorLavender => 'Lavender';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorSalmon => 'Salmon';

  @override
  String get colorCharcoal => 'Charcoal';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorTaupe => 'Taupe';

  @override
  String loadError(String error) {
    return 'Couldn\'t load your data. Details: $error';
  }

  @override
  String get addTask => 'Add task';

  @override
  String get taskNameHint => 'Task name';

  @override
  String get descriptionHint => 'Description';

  @override
  String get taskCompleted => 'Task completed';

  @override
  String get taskMoved => 'Task moved';

  @override
  String get dueChanged => 'Due date changed';

  @override
  String get actionUndo => 'Undo';

  @override
  String get deleteTaskTitle => 'Delete task?';

  @override
  String deleteTaskBody(String name) {
    return '\"$name\" and its sub-tasks will be deleted.';
  }

  @override
  String get viewOptions => 'View';

  @override
  String get completedTasks => 'Completed tasks';

  @override
  String get dueToday => 'Today';

  @override
  String get dueTomorrow => 'Tomorrow';

  @override
  String get dueYesterday => 'Yesterday';

  @override
  String get dueWeekend => 'This weekend';

  @override
  String get dueNextWeek => 'Next week';

  @override
  String get noDue => 'No date';

  @override
  String get pickDate => 'Pick a date…';

  @override
  String get addTime => 'Add time';

  @override
  String get removeTime => 'Remove time';

  @override
  String get fieldProject => 'Project';

  @override
  String get fieldDue => 'Date';

  @override
  String get fieldDeadline => 'Deadline';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldLabels => 'Labels';

  @override
  String get fieldDuration => 'Duration';

  @override
  String get noDeadline => 'No deadline';

  @override
  String get noDuration => 'No duration';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String priorityN(int n) {
    return 'Priority $n';
  }

  @override
  String get subtasks => 'Sub-tasks';

  @override
  String get addSubtask => 'Add sub-task';

  @override
  String get showCompleted => 'Show completed';

  @override
  String get hideCompleted => 'Hide completed';

  @override
  String get completeTask => 'Complete';

  @override
  String get reopenTask => 'Reopen';

  @override
  String createLabel(String name) {
    return 'Create label \"$name\"';
  }

  @override
  String get labelSearchHint => 'Label';

  @override
  String get actionDone => 'Done';

  @override
  String actionFailed(String error) {
    return 'Couldn\'t complete the action. Details: $error';
  }
}

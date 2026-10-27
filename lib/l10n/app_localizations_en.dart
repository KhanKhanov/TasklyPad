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
  String startupBadProfile(String name) {
    return 'Profile name \"$name\" is not valid: use lowercase Latin letters, digits and hyphens, up to 32 characters. Your data was not changed.';
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

  @override
  String get filtersAndLabels => 'Filters & Labels';

  @override
  String get labelsHeader => 'Labels';

  @override
  String get addLabel => 'Add label';

  @override
  String get editLabel => 'Edit label';

  @override
  String get deleteLabel => 'Delete label';

  @override
  String get deleteLabelTitle => 'Delete label?';

  @override
  String deleteLabelBody(String name) {
    return 'The label \"$name\" will be removed from all tasks.';
  }

  @override
  String get noLabels => 'No labels yet';

  @override
  String get previousTask => 'Previous task';

  @override
  String get nextTask => 'Next task';

  @override
  String get settings => 'Settings';

  @override
  String get syncSection => 'Sync';

  @override
  String get syncFolder => 'Sync folder';

  @override
  String get syncFolderNone =>
      'No folder chosen — your data is on this device only.';

  @override
  String get syncFolderHint =>
      'Choose a shared OneDrive, Google Drive or Syncthing folder: the app creates a planner-sync folder in it. Choose the same folder on your other devices.';

  @override
  String get chooseFolder => 'Choose folder…';

  @override
  String get changeFolder => 'Change folder…';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncRunning => 'Syncing…';

  @override
  String syncLast(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncIssues(int count) {
    return 'Files from other devices not read yet: $count. The cloud may still be downloading them — I\'ll retry on the next sync.';
  }

  @override
  String get syncErrorFormat =>
      'The folder was written by a newer version of the app. Update the app on this device — nothing was written to the folder.';

  @override
  String get syncErrorBusy =>
      'These data are already syncing — I\'ll retry later.';

  @override
  String get syncErrorRetiredUnread =>
      'Folder not changed: some changes of the ticked devices in the previous folder couldn\'t be read. Try again later.';

  @override
  String get retiredUnreadTitle => 'Not all changes were read';

  @override
  String get retiredUnreadBody =>
      'Some changes of the ticked devices in the previous folder couldn\'t be read: the cloud is still downloading files, a file is damaged, the device\'s clock is ahead or the previous folder is unavailable. You can wait and change the folder again. If you change it anyway, the unread changes won\'t reach the new folder; the previous folder stays as it is.';

  @override
  String get retiredUnreadAction => 'Change anyway';

  @override
  String syncErrorOther(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get changeFolderTitle => 'Change sync folder?';

  @override
  String changeFolderBody(String path) {
    return 'New folder: $path. The previous folder stays unchanged. Switch your other devices in use to the new folder too — they will move their own changes.';
  }

  @override
  String get changeFolderRetiredHint =>
      'Tick the devices you no longer use: this device will write their changes to the new folder. Don\'t tick a device you will switch later, or its new changes will look like a conflict.';

  @override
  String get changeFolderNoDevices =>
      'Couldn\'t read the devices of the previous folder: changes from other devices won\'t be moved to the new folder.';

  @override
  String get changeFolderAction => 'Change';

  @override
  String get folderConnected => 'Folder connected';

  @override
  String folderAdopted(int count) {
    return 'Folder connected. Changes from devices no longer in use were written to it: $count';
  }

  @override
  String folderAdoptedPartial(int adopted, int unreadable) {
    return 'Folder connected. Changes from devices no longer in use were written to it: $adopted. Not all changes were read from devices: $unreadable — the rest stays in the previous folder';
  }

  @override
  String folderUnreadable(int count) {
    return 'Folder connected. Not all changes were read from devices no longer in use: $count — the rest stays in the previous folder';
  }

  @override
  String get devicesHeader => 'Devices';

  @override
  String get thisDevice => 'this device';

  @override
  String get deviceUnnamed => 'Unnamed device';

  @override
  String deviceUpdated(String time) {
    return 'uploaded changes $time';
  }

  @override
  String get rebuildTitle => 'Rebuild database from the log';

  @override
  String get rebuildBody =>
      'Your data will be rebuilt from the change log. The log is not changed and no changes are lost. Use this if your data looks wrong.';

  @override
  String get rebuildAction => 'Rebuild';

  @override
  String get rebuildDone => 'Database rebuilt';

  @override
  String get syncUnsupported =>
      'Choosing a sync folder on this device is coming later.';

  @override
  String deviceWithProfile(String name, String profile) {
    return '$name ($profile)';
  }

  @override
  String deviceThis(String name) {
    return '$name — this device';
  }
}

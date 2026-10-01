// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mind Recall';

  @override
  String get modeEdit => 'Edit';

  @override
  String get modeLive => 'Live';

  @override
  String get modePreview => 'Preview';

  @override
  String get immersiveSourceHint => 'Markdown source';

  @override
  String get memos => 'Notes';

  @override
  String get newMemo => 'New';

  @override
  String get newFile => 'New file';

  @override
  String get newFolder => 'New folder';

  @override
  String get importDocument => 'Import document';

  @override
  String get importEncodingUnsupported => 'This file is not valid UTF-8 or GBK';

  @override
  String get goToParentDirectory => 'Go to parent folder';

  @override
  String get createFolderTitle => 'New folder';

  @override
  String get renameFolderTitle => 'Rename folder';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get folderNameHint => 'Enter a folder name';

  @override
  String get deleteFolderTitle => 'Delete folder';

  @override
  String deleteFolderConfirm(String title) {
    return 'Delete \"$title\" and everything inside? You can restore it from trash.';
  }

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get searchHint => 'Search keywords…';

  @override
  String get clear => 'Clear';

  @override
  String get caseSensitive => 'Case sensitive';

  @override
  String get caseInsensitive => 'Ignore case';

  @override
  String searchResultCount(int count) {
    return '$count results found';
  }

  @override
  String get noSearchResults => 'No matches';

  @override
  String matchCount(int count) {
    return '$count matches';
  }

  @override
  String get emptyMemoList => 'No notes yet\nTap + to create one';

  @override
  String get revealInExplorer => 'Show in file manager';

  @override
  String get rename => 'Rename';

  @override
  String get moveTo => 'Move to';

  @override
  String get setFolderColor => 'Set color';

  @override
  String get clearFolderColor => 'Clear color';

  @override
  String get folderColorTitle => 'Set color';

  @override
  String setFolderColorFailed(String error) {
    return 'Failed to set color: $error';
  }

  @override
  String get moveToTitle => 'Move to';

  @override
  String get moveToRoot => 'Root';

  @override
  String get delete => 'Delete';

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String get statusSaving => 'Saving…';

  @override
  String get statusSaved => 'Saved';

  @override
  String get statusError => 'Save failed';

  @override
  String get statusEditing => 'Editing';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSectionFormat => 'Format';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsFileSort => 'File sort';

  @override
  String get fileSortModifiedTime => 'Modified time';

  @override
  String get fileSortName => 'Name';

  @override
  String get settingsDebug => 'Debug';

  @override
  String get settingsDebugEnable => 'Enable debugging';

  @override
  String get settingsDebugShowFps => 'Show FPS';

  @override
  String get settingsDebugShowImeHud => 'Show IME status';

  @override
  String get settingsDebugShowCursorHud => 'Show cursor status';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupHint =>
      'Export notes and settings to a folder. After reinstall, import from that backup.';

  @override
  String get settingsTrash => 'Trash';

  @override
  String get settingsTrashHint =>
      'Notes with content go to trash on delete. Restore or empty them here.';

  @override
  String get exportData => 'Export data';

  @override
  String get importData => 'Import data';

  @override
  String get restoreFromTrash => 'Restore from trash';

  @override
  String get emptyTrash => 'Empty trash';

  @override
  String get emptyTrashConfirmTitle => 'Empty trash';

  @override
  String get emptyTrashConfirmMessage =>
      'Permanently delete all notes in trash?';

  @override
  String get emptyTrashSuccess => 'Trash emptied';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get restoreTrashTitle => 'Restore from trash';

  @override
  String restoreTrashSuccess(int count) {
    return 'Restored $count notes';
  }

  @override
  String get pinMemo => 'Pin';

  @override
  String get unpinMemo => 'Unpin';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String exportSuccess(String path) {
    return 'Exported to: $path';
  }

  @override
  String importSuccess(int count) {
    return 'Imported $count notes';
  }

  @override
  String get importConfirmTitle => 'Import backup';

  @override
  String get importConfirmMessage => 'Choose how to import.';

  @override
  String get importModeMerge => 'Merge';

  @override
  String get importModeMergeHint => 'Merge backup data into local data.';

  @override
  String get importModeOverwrite => 'Overwrite';

  @override
  String get importModeOverwriteHint =>
      'Replace local data with the backup. Some files may be deleted.';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get backupPickCancelled => 'Cancelled';

  @override
  String get storageAllFilesAccessRequired =>
      'Allow All files access in system settings, then try again.';

  @override
  String get fontSizeSmall => 'S';

  @override
  String get fontSizeMedium => 'M';

  @override
  String get fontSizeLarge => 'L';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get toolbarInsertLink => 'Insert link';

  @override
  String get linkDialogTitle => 'Insert link';

  @override
  String get linkSelectDocument => 'Choose document';

  @override
  String get linkSelectDocumentTitle => 'Choose document';

  @override
  String get linkNoOtherDocuments => 'No other documents available';

  @override
  String get linkUrlLabel => 'URL';

  @override
  String get linkUrlHint => 'https://… or document title';

  @override
  String get linkUrlHintMobile => 'https://… or document title';

  @override
  String get linkUrlHintDesktop => 'https://… or ./note.md';

  @override
  String get linkTextLabel => 'Display text';

  @override
  String linkOpenFailed(String error) {
    return 'Unable to open link: $error';
  }

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get titleHint => 'Leave empty to use the first line as title';

  @override
  String get untitled => 'Untitled';

  @override
  String get emptyBodyHint => 'Tap here to enter text';

  @override
  String get deleteMemoTitle => 'Delete note';

  @override
  String deleteMemoConfirm(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get renameTitle => 'Rename';

  @override
  String get renameLabel => 'Title';

  @override
  String get renameHint => 'Enter a new title';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String openFailed(String error) {
    return 'Failed to open: $error';
  }

  @override
  String createFailed(String error) {
    return 'Failed to create: $error';
  }

  @override
  String get imageReadFailed => 'Unable to read the selected image';

  @override
  String insertImageFailed(String error) {
    return 'Failed to insert image: $error';
  }

  @override
  String get renamed => 'Renamed';

  @override
  String renameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String get moved => 'Moved';

  @override
  String moveFailed(String error) {
    return 'Move failed: $error';
  }

  @override
  String revealFailed(String error) {
    return 'Unable to open folder: $error';
  }

  @override
  String get deleted => 'Deleted';

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get previewEmpty => 'Nothing to preview';

  @override
  String get imageLoadFailed => 'Unable to load image';

  @override
  String get toolbarH1 => 'Heading 1';

  @override
  String get toolbarH2 => 'Heading 2';

  @override
  String get toolbarH3 => 'Heading 3';

  @override
  String get toolbarBold => 'Bold';

  @override
  String get toolbarItalic => 'Italic';

  @override
  String get toolbarStrikethrough => 'Strikethrough';

  @override
  String get toolbarCode => 'Inline code';

  @override
  String get toolbarBulletList => 'Bullet list';

  @override
  String get toolbarOrderedList => 'Numbered list';

  @override
  String get toolbarTaskList => 'Checklist';

  @override
  String get toolbarQuote => 'Quote';

  @override
  String get toolbarCodeBlock => 'Code block';

  @override
  String get toolbarThematicBreak => 'Divider';

  @override
  String get toolbarParagraph => 'Paragraph';

  @override
  String get toolbarInsertImage => 'Insert image';

  @override
  String get codeBlockLanguageHint => 'Language';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'回念笔记'**
  String get appTitle;

  /// No description provided for @modeEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get modeEdit;

  /// No description provided for @modeLive.
  ///
  /// In zh, this message translates to:
  /// **'实时'**
  String get modeLive;

  /// No description provided for @modePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get modePreview;

  /// No description provided for @immersiveSourceHint.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 源码'**
  String get immersiveSourceHint;

  /// No description provided for @memos.
  ///
  /// In zh, this message translates to:
  /// **'备忘录'**
  String get memos;

  /// No description provided for @newMemo.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get newMemo;

  /// No description provided for @newFile.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get newFile;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @importDocument.
  ///
  /// In zh, this message translates to:
  /// **'导入文档'**
  String get importDocument;

  /// No description provided for @importEncodingUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'无法按 UTF-8 或 GBK 读取该文件'**
  String get importEncodingUnsupported;

  /// No description provided for @goToParentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'返回上级目录'**
  String get goToParentDirectory;

  /// No description provided for @createFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get createFolderTitle;

  /// No description provided for @renameFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件夹'**
  String get renameFolderTitle;

  /// No description provided for @folderNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名'**
  String get folderNameLabel;

  /// No description provided for @folderNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入文件夹名称'**
  String get folderNameHint;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除文件夹'**
  String get deleteFolderTitle;

  /// No description provided for @deleteFolderConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{title}」及其全部内容吗？可在回收站恢复。'**
  String deleteFolderConfirm(String title);

  /// No description provided for @collapseSidebar.
  ///
  /// In zh, this message translates to:
  /// **'收起侧栏'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In zh, this message translates to:
  /// **'展开侧栏'**
  String get expandSidebar;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索关键字…'**
  String get searchHint;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @caseSensitive.
  ///
  /// In zh, this message translates to:
  /// **'区分大小写'**
  String get caseSensitive;

  /// No description provided for @caseInsensitive.
  ///
  /// In zh, this message translates to:
  /// **'忽略大小写'**
  String get caseInsensitive;

  /// No description provided for @searchResultCount.
  ///
  /// In zh, this message translates to:
  /// **'找到 {count} 个结果'**
  String searchResultCount(int count);

  /// No description provided for @noSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'无匹配结果'**
  String get noSearchResults;

  /// No description provided for @matchCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 处匹配'**
  String matchCount(int count);

  /// No description provided for @emptyMemoList.
  ///
  /// In zh, this message translates to:
  /// **'暂无文件\n点击 + 新建'**
  String get emptyMemoList;

  /// No description provided for @revealInExplorer.
  ///
  /// In zh, this message translates to:
  /// **'在资源管理器中显示'**
  String get revealInExplorer;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @moveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到'**
  String get moveTo;

  /// No description provided for @setFolderColor.
  ///
  /// In zh, this message translates to:
  /// **'设置颜色'**
  String get setFolderColor;

  /// No description provided for @clearFolderColor.
  ///
  /// In zh, this message translates to:
  /// **'清除颜色'**
  String get clearFolderColor;

  /// No description provided for @folderColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置颜色'**
  String get folderColorTitle;

  /// No description provided for @setFolderColorFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置颜色失败：{error}'**
  String setFolderColorFailed(String error);

  /// No description provided for @moveToTitle.
  ///
  /// In zh, this message translates to:
  /// **'移动到'**
  String get moveToTitle;

  /// No description provided for @moveToRoot.
  ///
  /// In zh, this message translates to:
  /// **'根目录'**
  String get moveToRoot;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @todayAt.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In zh, this message translates to:
  /// **'昨天 {time}'**
  String yesterdayAt(String time);

  /// No description provided for @dateAt.
  ///
  /// In zh, this message translates to:
  /// **'{date} {time}'**
  String dateAt(String date, String time);

  /// No description provided for @statusSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get statusSaving;

  /// No description provided for @statusSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get statusSaved;

  /// No description provided for @statusError.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get statusError;

  /// No description provided for @statusEditing.
  ///
  /// In zh, this message translates to:
  /// **'编辑中'**
  String get statusEditing;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤回'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsSectionFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get settingsSectionFormat;

  /// No description provided for @settingsSectionData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsSectionData;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get settingsFontSize;

  /// No description provided for @settingsFileSort.
  ///
  /// In zh, this message translates to:
  /// **'文件排序'**
  String get settingsFileSort;

  /// No description provided for @fileSortModifiedTime.
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get fileSortModifiedTime;

  /// No description provided for @fileSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get fileSortName;

  /// No description provided for @settingsDebug.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get settingsDebug;

  /// No description provided for @settingsDebugEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用调试'**
  String get settingsDebugEnable;

  /// No description provided for @settingsDebugShowFps.
  ///
  /// In zh, this message translates to:
  /// **'显示帧率'**
  String get settingsDebugShowFps;

  /// No description provided for @settingsDebugShowImeHud.
  ///
  /// In zh, this message translates to:
  /// **'显示IME状态'**
  String get settingsDebugShowImeHud;

  /// No description provided for @settingsDebugShowCursorHud.
  ///
  /// In zh, this message translates to:
  /// **'显示光标状态'**
  String get settingsDebugShowCursorHud;

  /// No description provided for @settingsBackup.
  ///
  /// In zh, this message translates to:
  /// **'数据备份'**
  String get settingsBackup;

  /// No description provided for @settingsBackupHint.
  ///
  /// In zh, this message translates to:
  /// **'导出文档与用户配置到指定文件夹；重装后可从备份导入恢复。'**
  String get settingsBackupHint;

  /// No description provided for @settingsTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get settingsTrash;

  /// No description provided for @settingsTrashHint.
  ///
  /// In zh, this message translates to:
  /// **'有内容的文档删除后会先进入回收站；可在此恢复或清空。'**
  String get settingsTrashHint;

  /// No description provided for @exportData.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In zh, this message translates to:
  /// **'导入数据'**
  String get importData;

  /// No description provided for @restoreFromTrash.
  ///
  /// In zh, this message translates to:
  /// **'从回收站恢复'**
  String get restoreFromTrash;

  /// No description provided for @emptyTrash.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get emptyTrash;

  /// No description provided for @emptyTrashConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get emptyTrashConfirmTitle;

  /// No description provided for @emptyTrashConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将永久删除回收站内全部文档，是否继续？'**
  String get emptyTrashConfirmMessage;

  /// No description provided for @emptyTrashSuccess.
  ///
  /// In zh, this message translates to:
  /// **'回收站已清空'**
  String get emptyTrashSuccess;

  /// No description provided for @trashEmpty.
  ///
  /// In zh, this message translates to:
  /// **'回收站为空'**
  String get trashEmpty;

  /// No description provided for @restoreTrashTitle.
  ///
  /// In zh, this message translates to:
  /// **'从回收站恢复'**
  String get restoreTrashTitle;

  /// No description provided for @restoreTrashSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已恢复 {count} 篇文档'**
  String restoreTrashSuccess(int count);

  /// No description provided for @pinMemo.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinMemo;

  /// No description provided for @unpinMemo.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpinMemo;

  /// No description provided for @appVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String appVersion(String version);

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导出到：{path}'**
  String exportSuccess(String path);

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 篇文档'**
  String importSuccess(int count);

  /// No description provided for @importConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入备份'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'请选择导入方式。'**
  String get importConfirmMessage;

  /// No description provided for @importModeMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并数据'**
  String get importModeMerge;

  /// No description provided for @importModeMergeHint.
  ///
  /// In zh, this message translates to:
  /// **'将备份数据合并入本地数据。'**
  String get importModeMergeHint;

  /// No description provided for @importModeOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖数据'**
  String get importModeOverwrite;

  /// No description provided for @importModeOverwriteHint.
  ///
  /// In zh, this message translates to:
  /// **'将备份数据替换本地数据，可能会有文件被删除。'**
  String get importModeOverwriteHint;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(String error);

  /// No description provided for @backupPickCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get backupPickCancelled;

  /// No description provided for @storageAllFilesAccessRequired.
  ///
  /// In zh, this message translates to:
  /// **'请在系统设置中允许「所有文件访问」后再试。'**
  String get storageAllFilesAccessRequired;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get fontSizeMedium;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontSizeLarge;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @toolbarInsertLink.
  ///
  /// In zh, this message translates to:
  /// **'插入链接'**
  String get toolbarInsertLink;

  /// No description provided for @linkDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'插入链接'**
  String get linkDialogTitle;

  /// No description provided for @linkSelectDocument.
  ///
  /// In zh, this message translates to:
  /// **'选择文档'**
  String get linkSelectDocument;

  /// No description provided for @linkSelectDocumentTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文档'**
  String get linkSelectDocumentTitle;

  /// No description provided for @linkNoOtherDocuments.
  ///
  /// In zh, this message translates to:
  /// **'暂无其他可链接的文档'**
  String get linkNoOtherDocuments;

  /// No description provided for @linkUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'链接地址'**
  String get linkUrlLabel;

  /// No description provided for @linkUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://… 或文档标题'**
  String get linkUrlHint;

  /// No description provided for @linkUrlHintMobile.
  ///
  /// In zh, this message translates to:
  /// **'https://… 或文档标题'**
  String get linkUrlHintMobile;

  /// No description provided for @linkUrlHintDesktop.
  ///
  /// In zh, this message translates to:
  /// **'https://… 或 ./笔记文件.md'**
  String get linkUrlHintDesktop;

  /// No description provided for @linkTextLabel.
  ///
  /// In zh, this message translates to:
  /// **'显示文字'**
  String get linkTextLabel;

  /// No description provided for @linkOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接：{error}'**
  String linkOpenFailed(String error);

  /// No description provided for @titleOptional.
  ///
  /// In zh, this message translates to:
  /// **'标题（可选）'**
  String get titleOptional;

  /// No description provided for @titleHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用正文首行作为标题'**
  String get titleHint;

  /// No description provided for @untitled.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get untitled;

  /// No description provided for @emptyBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击此处输入文本'**
  String get emptyBodyHint;

  /// No description provided for @deleteMemoTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除备忘录'**
  String get deleteMemoTitle;

  /// No description provided for @deleteMemoConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{title}」吗？此操作不可恢复。'**
  String deleteMemoConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @renameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameTitle;

  /// No description provided for @renameLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get renameLabel;

  /// No description provided for @renameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新标题'**
  String get renameHint;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailed(String error);

  /// No description provided for @openFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开失败：{error}'**
  String openFailed(String error);

  /// No description provided for @createFailed.
  ///
  /// In zh, this message translates to:
  /// **'新建失败：{error}'**
  String createFailed(String error);

  /// No description provided for @imageReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选图片'**
  String get imageReadFailed;

  /// No description provided for @insertImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'插入图片失败：{error}'**
  String insertImageFailed(String error);

  /// No description provided for @renamed.
  ///
  /// In zh, this message translates to:
  /// **'已重命名'**
  String get renamed;

  /// No description provided for @renameFailed.
  ///
  /// In zh, this message translates to:
  /// **'重命名失败：{error}'**
  String renameFailed(String error);

  /// No description provided for @moved.
  ///
  /// In zh, this message translates to:
  /// **'已移动'**
  String get moved;

  /// No description provided for @moveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移动失败：{error}'**
  String moveFailed(String error);

  /// No description provided for @revealFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开目录：{error}'**
  String revealFailed(String error);

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(String error);

  /// No description provided for @moreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get moreActions;

  /// No description provided for @previewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容可预览'**
  String get previewEmpty;

  /// No description provided for @imageLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载图片'**
  String get imageLoadFailed;

  /// No description provided for @toolbarH1.
  ///
  /// In zh, this message translates to:
  /// **'一级标题'**
  String get toolbarH1;

  /// No description provided for @toolbarH2.
  ///
  /// In zh, this message translates to:
  /// **'二级标题'**
  String get toolbarH2;

  /// No description provided for @toolbarH3.
  ///
  /// In zh, this message translates to:
  /// **'三级标题'**
  String get toolbarH3;

  /// No description provided for @toolbarBold.
  ///
  /// In zh, this message translates to:
  /// **'粗体'**
  String get toolbarBold;

  /// No description provided for @toolbarItalic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get toolbarItalic;

  /// No description provided for @toolbarStrikethrough.
  ///
  /// In zh, this message translates to:
  /// **'删除线'**
  String get toolbarStrikethrough;

  /// No description provided for @toolbarCode.
  ///
  /// In zh, this message translates to:
  /// **'行内代码'**
  String get toolbarCode;

  /// No description provided for @toolbarBulletList.
  ///
  /// In zh, this message translates to:
  /// **'无序列表'**
  String get toolbarBulletList;

  /// No description provided for @toolbarOrderedList.
  ///
  /// In zh, this message translates to:
  /// **'有序列表'**
  String get toolbarOrderedList;

  /// No description provided for @toolbarTaskList.
  ///
  /// In zh, this message translates to:
  /// **'勾选列表'**
  String get toolbarTaskList;

  /// No description provided for @toolbarQuote.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get toolbarQuote;

  /// No description provided for @toolbarCodeBlock.
  ///
  /// In zh, this message translates to:
  /// **'代码块'**
  String get toolbarCodeBlock;

  /// No description provided for @toolbarThematicBreak.
  ///
  /// In zh, this message translates to:
  /// **'分割线'**
  String get toolbarThematicBreak;

  /// No description provided for @toolbarParagraph.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get toolbarParagraph;

  /// No description provided for @toolbarInsertImage.
  ///
  /// In zh, this message translates to:
  /// **'插入图片'**
  String get toolbarInsertImage;

  /// No description provided for @codeBlockLanguageHint.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get codeBlockLanguageHint;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

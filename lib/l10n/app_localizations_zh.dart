// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '回念笔记';

  @override
  String get modeEdit => '编辑';

  @override
  String get modeLive => '实时';

  @override
  String get modePreview => '预览';

  @override
  String get immersiveSourceHint => 'Markdown 源码';

  @override
  String get memos => '备忘录';

  @override
  String get newMemo => '新建';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get goToParentDirectory => '返回上级目录';

  @override
  String get createFolderTitle => '新建文件夹';

  @override
  String get renameFolderTitle => '重命名文件夹';

  @override
  String get folderNameLabel => '文件夹名';

  @override
  String get folderNameHint => '输入文件夹名称';

  @override
  String get deleteFolderTitle => '删除文件夹';

  @override
  String deleteFolderConfirm(String title) {
    return '确定删除「$title」及其全部内容吗？可在回收站恢复。';
  }

  @override
  String get collapseSidebar => '收起侧栏';

  @override
  String get expandSidebar => '展开侧栏';

  @override
  String get searchHint => '搜索关键字…';

  @override
  String get clear => '清除';

  @override
  String get caseSensitive => '区分大小写';

  @override
  String get caseInsensitive => '忽略大小写';

  @override
  String searchResultCount(int count) {
    return '找到 $count 个结果';
  }

  @override
  String get noSearchResults => '无匹配结果';

  @override
  String matchCount(int count) {
    return '$count 处匹配';
  }

  @override
  String get emptyMemoList => '暂无文件\n点击 + 新建';

  @override
  String get revealInExplorer => '在资源管理器中显示';

  @override
  String get rename => '重命名';

  @override
  String get moveTo => '移动到';

  @override
  String get setFolderColor => '设置颜色';

  @override
  String get clearFolderColor => '清除颜色';

  @override
  String get folderColorTitle => '设置颜色';

  @override
  String setFolderColorFailed(String error) {
    return '设置颜色失败：$error';
  }

  @override
  String get moveToTitle => '移动到';

  @override
  String get moveToRoot => '根目录';

  @override
  String get delete => '删除';

  @override
  String todayAt(String time) {
    return '今天 $time';
  }

  @override
  String yesterdayAt(String time) {
    return '昨天 $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String get statusSaving => '保存中…';

  @override
  String get statusSaved => '已保存';

  @override
  String get statusError => '保存失败';

  @override
  String get statusEditing => '编辑中';

  @override
  String get undo => '撤回';

  @override
  String get redo => '重做';

  @override
  String get settings => '设置';

  @override
  String get settingsSectionFormat => '格式';

  @override
  String get settingsSectionData => '数据';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsFontSize => '字体大小';

  @override
  String get settingsDebug => '调试';

  @override
  String get settingsDebugEnable => '启用调试';

  @override
  String get settingsDebugShowFps => '显示帧率';

  @override
  String get settingsDebugShowImeHud => '显示IME状态';

  @override
  String get settingsDebugShowCursorHud => '显示光标状态';

  @override
  String get settingsBackup => '数据备份';

  @override
  String get settingsBackupHint => '导出文档与用户配置到指定文件夹；重装后可从备份导入恢复。';

  @override
  String get settingsTrash => '回收站';

  @override
  String get settingsTrashHint => '有内容的文档删除后会先进入回收站；可在此恢复或清空。';

  @override
  String get exportData => '导出数据';

  @override
  String get importData => '导入数据';

  @override
  String get restoreFromTrash => '从回收站恢复';

  @override
  String get emptyTrash => '清空回收站';

  @override
  String get emptyTrashConfirmTitle => '清空回收站';

  @override
  String get emptyTrashConfirmMessage => '将永久删除回收站内全部文档，是否继续？';

  @override
  String get emptyTrashSuccess => '回收站已清空';

  @override
  String get trashEmpty => '回收站为空';

  @override
  String get restoreTrashTitle => '从回收站恢复';

  @override
  String restoreTrashSuccess(int count) {
    return '已恢复 $count 篇文档';
  }

  @override
  String get pinMemo => '置顶';

  @override
  String get unpinMemo => '取消置顶';

  @override
  String appVersion(String version) {
    return '版本 $version';
  }

  @override
  String exportSuccess(String path) {
    return '已导出到：$path';
  }

  @override
  String importSuccess(int count) {
    return '已导入 $count 篇文档';
  }

  @override
  String get importConfirmTitle => '导入备份';

  @override
  String get importConfirmMessage => '请选择导入方式。';

  @override
  String get importModeMerge => '合并数据';

  @override
  String get importModeMergeHint => '将备份数据合并入本地数据。';

  @override
  String get importModeOverwrite => '覆盖数据';

  @override
  String get importModeOverwriteHint => '将备份数据替换本地数据，可能会有文件被删除。';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get backupPickCancelled => '已取消';

  @override
  String get storageAllFilesAccessRequired => '请在系统设置中允许「所有文件访问」后再试。';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeMedium => '中';

  @override
  String get fontSizeLarge => '大';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get toolbarInsertLink => '插入链接';

  @override
  String get linkDialogTitle => '插入链接';

  @override
  String get linkSelectDocument => '选择文档';

  @override
  String get linkSelectDocumentTitle => '选择文档';

  @override
  String get linkNoOtherDocuments => '暂无其他可链接的文档';

  @override
  String get linkUrlLabel => '链接地址';

  @override
  String get linkUrlHint => 'https://… 或文档标题';

  @override
  String get linkUrlHintMobile => 'https://… 或文档标题';

  @override
  String get linkUrlHintDesktop => 'https://… 或 ./笔记文件.md';

  @override
  String get linkTextLabel => '显示文字';

  @override
  String linkOpenFailed(String error) {
    return '无法打开链接：$error';
  }

  @override
  String get titleOptional => '标题（可选）';

  @override
  String get titleHint => '留空则使用正文首行作为标题';

  @override
  String get untitled => '无标题';

  @override
  String get emptyBodyHint => '点击此处输入文本';

  @override
  String get deleteMemoTitle => '删除备忘录';

  @override
  String deleteMemoConfirm(String title) {
    return '确定删除「$title」吗？此操作不可恢复。';
  }

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get renameTitle => '重命名';

  @override
  String get renameLabel => '标题';

  @override
  String get renameHint => '输入新标题';

  @override
  String loadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String openFailed(String error) {
    return '打开失败：$error';
  }

  @override
  String createFailed(String error) {
    return '新建失败：$error';
  }

  @override
  String get imageReadFailed => '无法读取所选图片';

  @override
  String insertImageFailed(String error) {
    return '插入图片失败：$error';
  }

  @override
  String get renamed => '已重命名';

  @override
  String renameFailed(String error) {
    return '重命名失败：$error';
  }

  @override
  String get moved => '已移动';

  @override
  String moveFailed(String error) {
    return '移动失败：$error';
  }

  @override
  String revealFailed(String error) {
    return '无法打开目录：$error';
  }

  @override
  String get deleted => '已删除';

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get moreActions => '更多操作';

  @override
  String get previewEmpty => '暂无内容可预览';

  @override
  String get imageLoadFailed => '无法加载图片';

  @override
  String get toolbarH1 => '一级标题';

  @override
  String get toolbarH2 => '二级标题';

  @override
  String get toolbarH3 => '三级标题';

  @override
  String get toolbarBold => '粗体';

  @override
  String get toolbarItalic => '斜体';

  @override
  String get toolbarCode => '行内代码';

  @override
  String get toolbarBulletList => '无序列表';

  @override
  String get toolbarOrderedList => '有序列表';

  @override
  String get toolbarTaskList => '勾选列表';

  @override
  String get toolbarQuote => '引用';

  @override
  String get toolbarThematicBreak => '分割线';

  @override
  String get toolbarParagraph => '正文';

  @override
  String get toolbarInsertImage => '插入图片';
}

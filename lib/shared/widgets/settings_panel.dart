import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/user_preferences_service.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.prefsService,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onFontSizeChanged,
    this.onDebugToolsChanged,
    this.onDebugShowFpsChanged,
    this.onDebugShowImeHudChanged,
    this.onDebugShowCursorHudChanged,
    this.appVersionLabel,
    this.onExportData,
    this.onImportData,
    this.onEmptyTrash,
    this.onRestoreFromTrash,
    this.isTransferBusy = false,
  });

  /// 大类标题与首项之间的间距。
  static const _sectionHeaderGap = 12.0;

  /// 同一大类内相邻项之间的间距。
  static const _sectionItemGap = 20.0;

  /// 大类之间的间距。
  static const _sectionGap = 28.0;

  /// 控件标签与控件之间的间距。
  static const _labelGap = 8.0;

  /// 说明文字与下方按钮之间的间距。
  static const _hintToActionGap = 12.0;

  /// 同一组按钮之间的间距。
  static const _actionGap = 8.0;

  /// 调试子开关相对总开关的左侧缩进。
  static const _debugSubSwitchIndent = 16.0;

  final UserPreferencesService prefsService;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<AppFontSize> onFontSizeChanged;
  final ValueChanged<bool>? onDebugToolsChanged;
  final ValueChanged<bool>? onDebugShowFpsChanged;
  final ValueChanged<bool>? onDebugShowImeHudChanged;
  final ValueChanged<bool>? onDebugShowCursorHudChanged;
  final String? appVersionLabel;
  final VoidCallback? onExportData;
  final VoidCallback? onImportData;
  final VoidCallback? onEmptyTrash;
  final VoidCallback? onRestoreFromTrash;
  final bool isTransferBusy;

  ButtonStyle _segmentStyle(ThemeData theme) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.primary;
        }
        return theme.colorScheme.onSurfaceVariant;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.primaryContainer.withValues(alpha: 0.45);
        }
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prefs = prefsService.preferences;
    final segmentStyle = _segmentStyle(theme);
    final showDebug = kDebugMode && onDebugToolsChanged != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.settings,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (appVersionLabel != null && appVersionLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.appVersion(appVersionLabel!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: _sectionGap),

            // —— 格式：语言 / 主题 / 字体 ——
            _SettingsSectionHeader(title: l10n.settingsSectionFormat),
            const SizedBox(height: _sectionHeaderGap),
            Text(l10n.settingsLanguage, style: theme.textTheme.titleSmall),
            const SizedBox(height: _labelGap),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: segmentStyle,
              segments: [
                ButtonSegment(value: 'zh', label: Text(l10n.languageChinese)),
                ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ],
              selected: {prefs.localeCode},
              onSelectionChanged: (selection) {
                onLocaleChanged(selection.first);
              },
            ),
            const SizedBox(height: _sectionItemGap),
            Text(l10n.settingsTheme, style: theme.textTheme.titleSmall),
            const SizedBox(height: _labelGap),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: segmentStyle,
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.nights_stay_outlined, size: 18),
                ),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (selection) {
                onThemeModeChanged(selection.first);
              },
            ),
            const SizedBox(height: _sectionItemGap),
            Text(l10n.settingsFontSize, style: theme.textTheme.titleSmall),
            const SizedBox(height: _labelGap),
            SegmentedButton<AppFontSize>(
              showSelectedIcon: false,
              style: segmentStyle,
              segments: [
                ButtonSegment(
                  value: AppFontSize.small,
                  label: Text(l10n.fontSizeSmall),
                ),
                ButtonSegment(
                  value: AppFontSize.medium,
                  label: Text(l10n.fontSizeMedium),
                ),
                ButtonSegment(
                  value: AppFontSize.large,
                  label: Text(l10n.fontSizeLarge),
                ),
              ],
              selected: {prefs.fontSize},
              onSelectionChanged: (selection) {
                onFontSizeChanged(selection.first);
              },
            ),

            const SizedBox(height: _sectionGap),

            // —— 数据：备份 / 回收站 ——
            _SettingsSectionHeader(title: l10n.settingsSectionData),
            const SizedBox(height: _sectionHeaderGap),
            Text(l10n.settingsBackup, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              l10n.settingsBackupHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: _hintToActionGap),
            FilledButton.tonalIcon(
              onPressed: isTransferBusy ? null : onExportData,
              icon: isTransferBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(l10n.exportData),
            ),
            const SizedBox(height: _actionGap),
            OutlinedButton.icon(
              onPressed: isTransferBusy ? null : onImportData,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.importData),
            ),
            const SizedBox(height: _sectionItemGap),
            Text(l10n.settingsTrash, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              l10n.settingsTrashHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: _hintToActionGap),
            OutlinedButton.icon(
              onPressed: isTransferBusy ? null : onRestoreFromTrash,
              icon: const Icon(Icons.restore_from_trash_outlined),
              label: Text(l10n.restoreFromTrash),
            ),
            const SizedBox(height: _actionGap),
            OutlinedButton.icon(
              onPressed: isTransferBusy ? null : onEmptyTrash,
              icon: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              label: Text(
                l10n.emptyTrash,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

            // —— 调试（仅 Debug 构建）：总开关 + 子开关 ——
            if (showDebug) ...[
              const SizedBox(height: _sectionGap),
              _SettingsSectionHeader(title: l10n.settingsDebug),
              const SizedBox(height: _sectionHeaderGap),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsDebugEnable),
                value: prefs.debugToolsEnabled,
                onChanged: onDebugToolsChanged,
              ),
              if (prefs.debugToolsEnabled) ...[
                Padding(
                  padding: const EdgeInsets.only(left: _debugSubSwitchIndent),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsDebugShowFps),
                    value: prefs.debugShowFps,
                    onChanged: onDebugShowFpsChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: _debugSubSwitchIndent),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsDebugShowImeHud),
                    value: prefs.debugShowImeHud,
                    onChanged: onDebugShowImeHudChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: _debugSubSwitchIndent),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsDebugShowCursorHud),
                    value: prefs.debugShowCursorHud,
                    onChanged: onDebugShowCursorHudChanged,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 设置面板大类标题（格式 / 数据 / 调试）。
class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/services/data_backup_service.dart';

/// 导入备份确认：合并或覆盖，必须二选一，默认合并。
class ImportBackupDialog extends StatefulWidget {
  const ImportBackupDialog({
    super.key,
    this.initialMode = DataBackupImportMode.merge,
  });

  final DataBackupImportMode initialMode;

  @override
  State<ImportBackupDialog> createState() => _ImportBackupDialogState();
}

class _ImportBackupDialogState extends State<ImportBackupDialog> {
  static const _modeListGap = 8.0;

  late DataBackupImportMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.importConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.importConfirmMessage),
          const SizedBox(height: _modeListGap),
          RadioGroup<DataBackupImportMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _mode = value);
            },
            child: Column(
              children: [
                RadioListTile<DataBackupImportMode>(
                  title: Text(l10n.importModeMerge),
                  subtitle: Text(l10n.importModeMergeHint),
                  value: DataBackupImportMode.merge,
                ),
                RadioListTile<DataBackupImportMode>(
                  title: Text(l10n.importModeOverwrite),
                  subtitle: Text(l10n.importModeOverwriteHint),
                  value: DataBackupImportMode.overwrite,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_mode),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

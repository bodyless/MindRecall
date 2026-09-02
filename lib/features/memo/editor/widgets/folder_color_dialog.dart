import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/models/memo_folder.dart';
import 'package:mind_recall/shared/widgets/rgb_color_picker.dart';

/// 确认结果：`colorHex == null` 表示清除自定义色。
class FolderColorDialogResult {
  const FolderColorDialogResult(this.colorHex);

  final String? colorHex;
}

/// 设置文件夹颜色；草稿仅在确定后返回。
class FolderColorDialog extends StatefulWidget {
  const FolderColorDialog({
    super.key,
    this.initialColorHex,
  });

  final String? initialColorHex;

  @override
  State<FolderColorDialog> createState() => _FolderColorDialogState();
}

class _FolderColorDialogState extends State<FolderColorDialog> {
  static const _unsetPickerColor = Color(0xFF808080);
  static const _previewSize = 48.0;
  static const _contentGap = 12.0;
  static const _previewBorderWidth = 1.0;
  static const _dialogContentWidth = 280.0;

  late String? _draftHex;
  late Color _pickerColor;

  @override
  void initState() {
    super.initState();
    final parsed = MemoFolder.parseColorHex(widget.initialColorHex);
    _draftHex = parsed;
    _pickerColor = parsed == null ? _unsetPickerColor : _colorFromHex(parsed);
  }

  void _onPickerChanged(Color color) {
    setState(() {
      _pickerColor = color;
      _draftHex = MemoFolder.formatColorHex(
        r: _byte(color.r),
        g: _byte(color.g),
        b: _byte(color.b),
      );
    });
  }

  void _clearDraft() {
    setState(() {
      _draftHex = null;
    });
  }

  void _submit() {
    Navigator.of(context).pop(FolderColorDialogResult(_draftHex));
  }

  static int _byte(double unit) => (unit * 255.0).round().clamp(0, 255);

  static Color _colorFromHex(String hex) {
    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final previewColor = _draftHex == null
        ? Colors.transparent
        : _colorFromHex(_draftHex!);

    return AlertDialog(
      title: Text(l10n.folderColorTitle),
      content: SizedBox(
        width: _dialogContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: _previewSize,
                height: _previewSize,
                decoration: BoxDecoration(
                  color: previewColor,
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: _previewBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: _contentGap),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _clearDraft,
                child: Text(l10n.clearFolderColor),
              ),
            ),
            const SizedBox(height: _contentGap),
            RgbColorPicker(
              value: _pickerColor,
              onChanged: _onPickerChanged,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

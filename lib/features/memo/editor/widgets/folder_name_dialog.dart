import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

/// 新建或重命名文件夹显示名。
class FolderNameDialog extends StatefulWidget {
  const FolderNameDialog({
    super.key,
    required this.title,
    this.initialName = '',
  });

  final String title;
  final String initialName;

  @override
  State<FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.folderNameLabel,
          hintText: l10n.folderNameHint,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
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

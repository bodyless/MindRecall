import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

/// 重命名备忘录标题。
class RenameMemoDialog extends StatefulWidget {
  const RenameMemoDialog({super.key, required this.initialTitle});

  final String initialTitle;

  @override
  State<RenameMemoDialog> createState() => _RenameMemoDialogState();
}

class _RenameMemoDialogState extends State<RenameMemoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.renameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.renameLabel,
          hintText: l10n.renameHint,
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

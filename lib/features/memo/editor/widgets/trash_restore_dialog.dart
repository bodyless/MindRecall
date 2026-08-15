import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/services/memo_trash_service.dart';

/// 从回收站多选恢复。
class TrashRestoreDialog extends StatefulWidget {
  const TrashRestoreDialog({super.key, required this.items});

  final List<TrashItem> items;

  @override
  State<TrashRestoreDialog> createState() => _TrashRestoreDialogState();
}

class _TrashRestoreDialogState extends State<TrashRestoreDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.restoreTrashTitle),
      content: SizedBox(
        width: 360,
        height: 360,
        child: ListView.builder(
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final checked = _selected.contains(item.id);
            return CheckboxListTile(
              value: checked,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(item.id);
                  } else {
                    _selected.remove(item.id);
                  }
                });
              },
              title: Text(item.displayTitle(l10n.untitled)),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.from(_selected)),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

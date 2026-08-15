import 'package:flutter/material.dart';
import 'package:mind_recall/features/memo/editor/markdown_link_actions.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/models/memo.dart';

/// 插入 Markdown 链接：网址或选择其它文档。
class LinkInsertDialog extends StatefulWidget {
  const LinkInsertDialog({
    super.key,
    this.initialText = '',
    required this.memos,
    this.currentMemoId,
    required this.useRelativeFileHref,
  });

  final String initialText;
  final List<Memo> memos;
  final String? currentMemoId;
  final bool useRelativeFileHref;

  @override
  State<LinkInsertDialog> createState() => _LinkInsertDialogState();
}

class _LinkInsertDialogState extends State<LinkInsertDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _textController;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _textController = TextEditingController(text: widget.initialText);
    _urlFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _urlFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _urlFocusNode.dispose();
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop((
      url: _urlController.text,
      text: _textController.text,
    ));
  }

  List<Memo> get _selectableMemos {
    final currentId = widget.currentMemoId;
    if (currentId == null) {
      return widget.memos;
    }
    return widget.memos.where((m) => m.id != currentId).toList(growable: false);
  }

  Future<void> _pickDocument() async {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _selectableMemos;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.linkNoOtherDocuments)));
      return;
    }

    final selected = await showModalBottomSheet<Memo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.linkSelectDocumentTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final memo = candidates[index];
                      final title = memo.displayTitle(l10n.untitled);
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(title),
                        onTap: () => Navigator.of(sheetContext).pop(memo),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    final title = selected.displayTitle(l10n.untitled);
    final href = MarkdownLinkActions.hrefForMemo(
      memo: selected,
      useRelativeFileHref: widget.useRelativeFileHref,
      untitledLabel: l10n.untitled,
    );
    setState(() {
      _urlController.text = href;
      _textController.text = title;
    });
    _urlFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urlHint = widget.useRelativeFileHref
        ? l10n.linkUrlHintDesktop
        : l10n.linkUrlHintMobile;
    return AlertDialog(
      title: Text(l10n.linkDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.linkSelectDocument),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              decoration: InputDecoration(
                labelText: l10n.linkUrlLabel,
                hintText: urlHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: l10n.linkTextLabel,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
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

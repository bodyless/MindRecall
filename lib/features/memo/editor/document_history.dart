/// 文档级撤回/重做：基于标题 + 正文快照，不依赖 TextField 控件栈。
class DocumentHistory {
  DocumentHistory({this.maxDepth = 100});

  final int maxDepth;

  final List<DocumentSnapshot> _undoStack = [];
  final List<DocumentSnapshot> _redoStack = [];
  DocumentSnapshot? _present;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void reset(DocumentSnapshot snapshot) {
    _undoStack.clear();
    _redoStack.clear();
    _present = snapshot;
  }

  /// 记录新状态；与当前相同时跳过。
  void record(DocumentSnapshot snapshot) {
    if (_present != null && _present == snapshot) {
      return;
    }
    if (_present != null) {
      _undoStack.add(_present!);
      if (_undoStack.length > maxDepth) {
        _undoStack.removeAt(0);
      }
    }
    _redoStack.clear();
    _present = snapshot;
  }

  DocumentSnapshot? undo(DocumentSnapshot current) {
    if (_undoStack.isEmpty) {
      return null;
    }
    _redoStack.add(current);
    final previous = _undoStack.removeLast();
    _present = previous;
    return previous;
  }

  DocumentSnapshot? redo(DocumentSnapshot current) {
    if (_redoStack.isEmpty) {
      return null;
    }
    _undoStack.add(current);
    final next = _redoStack.removeLast();
    _present = next;
    return next;
  }
}

class DocumentSnapshot {
  const DocumentSnapshot({required this.title, required this.content});

  final String title;
  final String content;

  @override
  bool operator ==(Object other) {
    return other is DocumentSnapshot &&
        other.title == title &&
        other.content == content;
  }

  @override
  int get hashCode => Object.hash(title, content);
}

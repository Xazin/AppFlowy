import 'package:flutter/material.dart';

import 'package:appflowy/plugins/document/presentation/editor_plugins/block_transaction_handler/block_transaction_handler.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

class ChildPageTransactionHandler extends BlockTransactionHandler {
  ChildPageTransactionHandler()
      : super(
          blockType: MentionBlockKeys.mention,
          isParagraphSubType: true,
        );

  @override
  void onRedo(
    BuildContext context,
    EditorState editorState,
    List<Node> before,
    List<Node> after,
  ) {}

  @override
  Future<void> onTransaction(
    BuildContext context,
    EditorState editorState,
    List<Node> added,
    List<Node> removed, {
    bool isUndoRedo = false,
    bool isPaste = false,
    bool isDraggingNode = false,
    String? parentViewId,
  }) async {}

  @override
  void onUndo(
    BuildContext context,
    EditorState editorState,
    List<Node> before,
    List<Node> after,
  ) {}
}

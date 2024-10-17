import 'package:appflowy/shared/clipboard_state.dart';
import 'package:flutter/material.dart';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/transaction_handler/editor_transaction_handler.dart';
import 'package:appflowy/plugins/trash/application/trash_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/snap_bar.dart';
import 'package:provider/provider.dart';

/// The data used to handle transactions for mentions.
///
/// [Node] is the block node.
/// [Map] is the data of the mention block.
/// [int] is the index of the mention block in the list of deltas (after transaction apply).
///
typedef MentionBlockData = (Node, Map<String, dynamic>, int);

const _pasteIdentifier = 'child_page_transaction';

class ChildPageTransactionHandler
    extends EditorTransactionHandler<MentionBlockData> {
  ChildPageTransactionHandler()
      : super(type: MentionBlockKeys.mention, isParagraphSubType: true);

  @override
  Future<void> onTransaction(
    BuildContext context,
    EditorState editorState,
    List<MentionBlockData> added,
    List<MentionBlockData> removed, {
    bool isCut = false,
    bool isUndoRedo = false,
    bool isPaste = false,
    bool isDraggingNode = false,
    String? parentViewId,
  }) async {
    if (isDraggingNode) {
      return;
    }

    for (final mention in removed) {
      if (!context.mounted) {
        return;
      }

      if (mention.$2[MentionBlockKeys.type] != MentionType.childPage.name) {
        continue;
      }

      await _handleDeletion(context, mention);
    }

    if (isPaste || isUndoRedo) {
      if (context.mounted) {
        context.read<ClipboardState>().startHandlingPaste(_pasteIdentifier);
      }

      for (final mention in added) {
        if (!context.mounted) {
          return;
        }

        if (mention.$2[MentionBlockKeys.type] != MentionType.childPage.name) {
          continue;
        }

        await _handleAddition(
          context,
          editorState,
          mention,
          isPaste,
          parentViewId,
          isCut,
        );
      }

      if (context.mounted) {
        context.read<ClipboardState>().endHandlingPaste(_pasteIdentifier);
      }
    }
  }

  Future<void> _handleDeletion(
    BuildContext context,
    MentionBlockData data,
  ) async {
    final viewId = data.$2[MentionBlockKeys.pageId];

    final result = await ViewBackendService.deleteView(viewId: viewId);
    result.fold(
      (_) {},
      (error) {
        Log.error(error);
        if (context.mounted) {
          showSnapBar(
            context,
            LocaleKeys.document_plugins_subPage_errors_failedDeletePage.tr(),
          );
        }
      },
    );
  }

  Future<void> _handleAddition(
    BuildContext context,
    EditorState editorState,
    MentionBlockData data,
    bool isPaste,
    String? parentViewId,
    bool isCut,
  ) async {
    if (parentViewId == null) {
      return;
    }

    final viewId = data.$2[MentionBlockKeys.pageId];
    if (isPaste && !isCut) {
      _handlePasteFromCopy(
        context,
        editorState,
        data.$1,
        data.$3,
        viewId,
        parentViewId,
      );
    } else {
      _handlePasteFromCut(viewId, parentViewId);
    }
  }

  void _handlePasteFromCut(String viewId, String parentViewId) async {
    // Attempt to restore from Trash just in case
    await TrashService.putback(viewId);

    final view = (await ViewBackendService.getView(viewId)).toNullable();
    if (view == null) {
      return Log.error('View not found: $viewId');
    }

    if (view.parentViewId == parentViewId) {
      return;
    }

    await ViewBackendService.moveViewV2(
      viewId: viewId,
      newParentId: parentViewId,
      prevViewId: null,
    );
  }

  void _handlePasteFromCopy(
    BuildContext context,
    EditorState editorState,
    Node node,
    int index,
    String viewId,
    String parentViewId,
  ) async {
    final view = (await ViewBackendService.getView(viewId)).toNullable();
    if (view == null) {
      return Log.error('View not found: $viewId');
    }

    final duplicatedViewOrFailure = await ViewBackendService.duplicate(
      view: view,
      openAfterDuplicate: false,
      includeChildren: true,
      syncAfterDuplicate: true,
      parentViewId: parentViewId,
    );

    await duplicatedViewOrFailure.fold(
      (newView) async {
        final deltaAttr = node.attributes['delta'] as List;

        final delta = deltaAttr[index];
        delta['attributes'][MentionBlockKeys.mention] = {
          MentionBlockKeys.type: MentionType.childPage.name,
          MentionBlockKeys.pageId: newView.id,
        };
        deltaAttr[index] = delta;

        // Replace the mention block with the new view id
        final transaction = editorState.transaction
          ..updateNode(
            node,
            {'delta': deltaAttr, ...node.attributes},
          );

        await editorState.apply(
          transaction,
          options: const ApplyOptions(recordUndo: false),
        );
      },
      (error) {
        Log.error(error);
        if (context.mounted) {
          showSnapBar(
            context,
            LocaleKeys.document_plugins_subPage_errors_failedDuplicatePage.tr(),
          );
        }
      },
    );
  }
}

import 'dart:async';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_block.dart';
import 'package:appflowy/plugins/inline_actions/inline_actions_result.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/application/workspace/prelude.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';

class InlinePageReferenceService {
  InlinePageReferenceService({required this.currentViewId}) {
    init();
  }

  final Completer _initCompleter = Completer<void>();
  final String currentViewId;

  late final ViewBackendService service;
  late final WorkspaceListener _workspaceListener;
  List<InlineActionsMenuItem> _items = [];
  List<InlineActionsMenuItem> _filtered = [];

  Future<void> init() async {
    service = const ViewBackendService();
    _initWorkspaceListener();

    final views = await service.fetchViews();
    _generatePageItems(views).then((value) {
      _items = value;
      _filtered = value;
      _initCompleter.complete();
    });
  }

  Future<void> _initWorkspaceListener() async {
    final userOrFailure = await getIt<AuthService>().getUser();
    final user = userOrFailure.fold((l) => null, (profile) => profile);

    final workspaceOrFailure =
        (await FolderEventGetCurrentWorkspace().send()).swap();
    final workspaceSettings =
        workspaceOrFailure.fold((l) => null, (workspace) => workspace);

    if (user != null && workspaceSettings != null) {
      _workspaceListener = WorkspaceListener(
        user: user,
        workspaceId: workspaceSettings.workspace.id,
      )..start(appsChanged: _appsChanged);
    }
  }

  void _appsChanged(Either<List<ViewPB>, FlowyError> viewsOrFailure) async =>
      viewsOrFailure.fold(
        (views) {
          _generatePageItems(views).then((value) {
            _items = value;
            _filtered = value;
          });
        },
        (_) => null,
      );

  Future<List<InlineActionsMenuItem>> _filterItems(String? search) async {
    await _initCompleter.future;

    if (search == null || search.isEmpty) {
      return _items;
    }

    return _items
        .where(
          (item) =>
              item.keywords != null &&
              item.keywords!.isNotEmpty &&
              item.keywords!.any(
                (keyword) => keyword.contains(search.toLowerCase()),
              ),
        )
        .toList();
  }

  Future<InlineActionsResult> inlinePageReferenceDelegate([
    String? search,
  ]) async {
    _filtered = await _filterItems(search);

    return InlineActionsResult(
      title: LocaleKeys.inlineActions_pageReference.tr(),
      results: _filtered,
    );
  }

  Future<List<InlineActionsMenuItem>> _generatePageItems(
    List<ViewPB> views,
  ) async {
    if (views.isEmpty) {
      return [];
    }

    final List<InlineActionsMenuItem> pages = [];
    views.sort(((a, b) => b.createTime.compareTo(a.createTime)));

    for (final view in views) {
      if (view.id == currentViewId) {
        continue;
      }

      final pageSelectionMenuItem = InlineActionsMenuItem(
        keywords: [view.name.toLowerCase()],
        label: view.name,
        onSelected: (context, editorState, menuService, replace) async {
          final selection = editorState.selection;
          if (selection == null || !selection.isCollapsed) {
            return;
          }

          final node = editorState.getNodeAtPath(selection.end.path);
          final delta = node?.delta;
          if (node == null || delta == null) {
            return;
          }

          // @page name -> $
          // preload the page infos
          pageMemorizer[view.id] = view;
          final transaction = editorState.transaction
            ..replaceText(
              node,
              replace.$1,
              replace.$2,
              '\$',
              attributes: {
                MentionBlockKeys.mention: {
                  MentionBlockKeys.type: MentionType.page.name,
                  MentionBlockKeys.pageId: view.id,
                }
              },
            );

          await editorState.apply(transaction);
        },
      );

      pages.add(pageSelectionMenuItem);
    }

    return pages;
  }
}

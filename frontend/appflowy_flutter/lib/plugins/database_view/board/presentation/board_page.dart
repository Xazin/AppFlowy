import 'dart:collection';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database_view/application/database_controller.dart';
import 'package:appflowy/plugins/database_view/application/field/field_controller.dart';
import 'package:appflowy/plugins/database_view/application/row/row_cache.dart';
import 'package:appflowy/plugins/database_view/application/row/row_controller.dart';
import 'package:appflowy/plugins/database_view/board/presentation/widgets/board_column_header.dart';
import 'package:appflowy/plugins/database_view/tar_bar/tab_bar_view.dart';
import 'package:appflowy/plugins/database_view/widgets/row/row_detail.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/row_entities.pb.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';

import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flowy_infra_ui/widget/error_page.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/card/cells/card_cell.dart';
import '../../widgets/card/card_cell_builder.dart';
import '../../widgets/row/cell_builder.dart';
import '../application/board_bloc.dart';
import '../../widgets/card/card.dart';
import 'toolbar/board_setting_bar.dart';
import 'ungrouped_items_button.dart';

class BoardPageTabBarBuilderImpl implements DatabaseTabBarItemBuilder {
  @override
  Widget content(
    BuildContext context,
    ViewPB view,
    DatabaseController controller,
    bool shrinkWrap,
  ) =>
      BoardPage(view: view, databaseController: controller);

  @override
  Widget settingBar(BuildContext context, DatabaseController controller) {
    return BoardSettingBar(
      key: _makeValueKey(controller),
      databaseController: controller,
    );
  }

  @override
  Widget settingBarExtension(
    BuildContext context,
    DatabaseController controller,
  ) =>
      const SizedBox.shrink();

  ValueKey _makeValueKey(DatabaseController controller) {
    return ValueKey(controller.viewId);
  }
}

class BoardPage extends StatelessWidget {
  BoardPage({
    required this.view,
    required this.databaseController,
    this.onEditStateChanged,
  }) : super(key: ValueKey(view.id));

  final ViewPB view;

  final DatabaseController databaseController;

  /// Called when edit state changed
  final VoidCallback? onEditStateChanged;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BoardBloc>(
      create: (context) => BoardBloc(
        view: view,
        databaseController: databaseController,
      )..add(const BoardEvent.initial()),
      child: BlocBuilder<BoardBloc, BoardState>(
        buildWhen: (p, c) => p.loadingState != c.loadingState,
        builder: (context, state) {
          return state.loadingState.map(
            loading: (_) =>
                const Center(child: CircularProgressIndicator.adaptive()),
            finish: (result) {
              return result.successOrFail.fold(
                (_) => BoardContent(
                  onEditStateChanged: onEditStateChanged,
                ),
                (err) => FlowyErrorPage.message(
                  err.toString(),
                  howToFix: LocaleKeys.errorDialog_howToFixFallback.tr(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BoardContent extends StatefulWidget {
  const BoardContent({
    super.key,
    this.onEditStateChanged,
  });

  final VoidCallback? onEditStateChanged;

  @override
  State<BoardContent> createState() => _BoardContentState();
}

class _BoardContentState extends State<BoardContent> {
  late AppFlowyBoardScrollController scrollManager;
  final renderHook = RowCardRenderHook<String>();

  final config = const AppFlowyBoardConfig(
    groupBackgroundColor: Color(0xffF7F8FC),
    headerPadding: EdgeInsets.symmetric(horizontal: 8),
    cardPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  );

  @override
  void initState() {
    super.initState();

    scrollManager = AppFlowyBoardScrollController();
    renderHook.addSelectOptionHook((options, groupId, _) {
      // The cell should hide if the option id is equal to the groupId.
      final isInGroup =
          options.where((element) => element.id == groupId).isNotEmpty;

      if (isInGroup || options.isEmpty) {
        return const SizedBox.shrink();
      }

      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardBloc, BoardState>(
      listener: (context, state) {
        _handleEditStateChanged(state, context);
        widget.onEditStateChanged?.call();
      },
      child: BlocBuilder<BoardBloc, BoardState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const VSpace(8.0),
              if (state.layoutSettings?.hideUngroupedColumn ?? false)
                _buildBoardHeader(context),
              Expanded(
                child: AppFlowyBoard(
                  boardScrollController: scrollManager,
                  scrollController: ScrollController(),
                  controller: context.read<BoardBloc>().boardController,
                  groupConstraints: const BoxConstraints.tightFor(width: 300),
                  config: const AppFlowyBoardConfig(
                    groupPadding: EdgeInsets.symmetric(horizontal: 4),
                    groupItemPadding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  leading: const HiddenGroupsColumn(),
                  headerBuilder: (_, groupData) =>
                      BlocProvider<BoardBloc>.value(
                    value: context.read<BoardBloc>(),
                    child: BoardColumnHeader(
                      groupData: groupData,
                      margin: config.headerPadding,
                    ),
                  ),
                  footerBuilder: _buildFooter,
                  cardBuilder: (_, column, columnItem) => _buildCard(
                    context,
                    column,
                    columnItem,
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoardHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        height: 24,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: UngroupedItemsButton(),
        ),
      ),
    );
  }

  void _handleEditStateChanged(BoardState state, BuildContext context) {
    if (state.isEditingRow && state.editingRow != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.editingRow!.index == null) {
          scrollManager.scrollToBottom(state.editingRow!.group.groupId);
        }
      });
    }
  }

  Widget _buildFooter(BuildContext context, AppFlowyGroupData columnData) {
    return AppFlowyGroupFooter(
      height: 50,
      margin: config.footerPadding,
      icon: SizedBox(
        height: 20,
        width: 20,
        child: FlowySvg(
          FlowySvgs.add_s,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
      title: FlowyText.medium(
        LocaleKeys.board_column_createNewCard.tr(),
        fontSize: 14,
      ),
      onAddButtonClick: () => context
          .read<BoardBloc>()
          .add(BoardEvent.createBottomRow(columnData.id)),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppFlowyGroupData afGroupData,
    AppFlowyGroupItem afGroupItem,
  ) {
    final boardBloc = context.read<BoardBloc>();
    final groupItem = afGroupItem as GroupItem;
    final groupData = afGroupData.customData as GroupData;
    final rowMeta = groupItem.row;
    final rowCache = boardBloc.getRowCache();

    /// Return placeholder widget if the rowCache is null.
    if (rowCache == null) return SizedBox.shrink(key: ObjectKey(groupItem));
    final cellCache = rowCache.cellCache;
    final fieldController = boardBloc.fieldController;
    final viewId = boardBloc.viewId;

    final cellBuilder = CardCellBuilder<String>(cellCache);
    final isEditing = boardBloc.state.isEditingRow &&
        boardBloc.state.editingRow?.row.id == groupItem.row.id;

    final groupItemId = groupItem.row.id + groupData.group.groupId;
    return AppFlowyGroupCard(
      key: ValueKey(groupItemId),
      margin: config.cardPadding,
      decoration: _makeBoxDecoration(context),
      child: RowCard<String>(
        rowMeta: rowMeta,
        viewId: viewId,
        rowCache: rowCache,
        cardData: groupData.group.groupId,
        groupingFieldId: groupItem.fieldInfo.id,
        groupId: groupData.group.groupId,
        isEditing: isEditing,
        cellBuilder: cellBuilder,
        renderHook: renderHook,
        openCard: (context) => _openCard(
          context: context,
          viewId: viewId,
          groupId: groupData.group.groupId,
          fieldController: fieldController,
          rowMeta: rowMeta,
          rowCache: rowCache,
        ),
        onStartEditing: () => boardBloc
            .add(BoardEvent.startEditingRow(groupData.group, groupItem.row)),
        onEndEditing: () =>
            boardBloc.add(BoardEvent.endEditingRow(groupItem.row.id)),
      ),
    );
  }

  BoxDecoration _makeBoxDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      border: Border.fromBorderSide(
        BorderSide(
          color: Theme.of(context).dividerColor,
          width: 1.4,
        ),
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 4,
          spreadRadius: 0,
          color: const Color(0xFF1F2329).withOpacity(0.02),
        ),
        BoxShadow(
          blurRadius: 4,
          spreadRadius: -2,
          color: const Color(0xFF1F2329).withOpacity(0.02),
        ),
      ],
    );
  }

  void _openCard({
    required BuildContext context,
    required String viewId,
    required String groupId,
    required FieldController fieldController,
    required RowMetaPB rowMeta,
    required RowCache rowCache,
  }) {
    final rowInfo = RowInfo(
      viewId: viewId,
      fields: UnmodifiableListView(fieldController.fieldInfos),
      rowMeta: rowMeta,
      rowId: rowMeta.id,
    );

    final dataController = RowController(
      rowMeta: rowInfo.rowMeta,
      viewId: rowInfo.viewId,
      rowCache: rowCache,
      groupId: groupId,
    );

    FlowyOverlay.show(
      context: context,
      builder: (BuildContext context) {
        return RowDetailPage(
          cellBuilder: GridCellBuilder(cellCache: dataController.cellCache),
          rowController: dataController,
        );
      },
    );
  }
}

class HiddenGroupsColumn extends StatefulWidget {
  const HiddenGroupsColumn({super.key});

  @override
  State<HiddenGroupsColumn> createState() => _HiddenGroupsColumnState();
}

class _HiddenGroupsColumnState extends State<HiddenGroupsColumn> {
  bool isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      alignment: AlignmentDirectional.topStart,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 150),
      child: isCollapsed
          ? Padding(
              padding: const EdgeInsets.fromLTRB(48, 16, 8, 8),
              child: _collapseExpandIcon(),
            )
          : SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hidden group title
                  Padding(
                    // padding: const EdgeInsets.only(left: 48),
                    padding: const EdgeInsets.fromLTRB(48, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: FlowyText.medium(
                            'Hidden groups',
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        _collapseExpandIcon(),
                      ],
                    ),
                  ),
                  // Hidden grouop cards
                  Expanded(
                    child: ListView.separated(
                      itemCount: 50,
                      itemBuilder: (context, index) => const HiddenGroupCard(),
                      separatorBuilder: (context, index) => const VSpace(2),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _collapseExpandIcon() {
    return FlowyTooltip(
      message: isCollapsed ? "Expand group" : "Collpase group",
      child: FlowyIconButton(
        width: 20,
        height: 20,
        icon: FlowySvg(
          isCollapsed
              ? FlowySvgs.pull_left_outlined_s
              : FlowySvgs.pull_left_outlined_s,
        ),
        iconColorOnHover: Theme.of(context).colorScheme.onSurface,
        onPressed: () => setState(() {
          isCollapsed = !isCollapsed;
        }),
      ),
    );
  }
}

class HiddenGroupCard extends StatefulWidget {
  const HiddenGroupCard({super.key});

  @override
  State<HiddenGroupCard> createState() => _HiddenGroupCardState();
}

class _HiddenGroupCardState extends State<HiddenGroupCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: FlowyHover(
        onHover: (isHovering) => setState(() => _isHovering = isHovering),
        resetHoverOnRebuild: false,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                Opacity(
                  opacity: _isHovering ? 1 : 0,
                  child: const HiddenGroupCardActions(),
                ),
                const HSpace(4),
                const FlowyText.medium(
                  'In progress',
                  fontSize: 12,
                  overflow: TextOverflow.clip,
                ),
                const HSpace(6),
                FlowyText.medium(
                  '6',
                  fontSize: 12,
                  overflow: TextOverflow.clip,
                  color: Theme.of(context).hintColor,
                ),
                const Spacer(),
                Opacity(
                  opacity: _isHovering ? 1 : 0,
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: FlowySvg(
                      FlowySvgs.show_m,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HiddenGroupCardActions extends StatelessWidget {
  const HiddenGroupCardActions({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      width: 14,
      child: FlowySvg(
        FlowySvgs.drag_element_s,
        color: Theme.of(context).hintColor,
      ),
    );
  }
}

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/database/board/mobile_board_content.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_state_container.dart';
import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/row/row_controller.dart';
import 'package:appflowy/plugins/database/board/application/board_selector_bloc.dart';
import 'package:appflowy/plugins/database/board/presentation/widgets/board_column_header.dart';
import 'package:appflowy/plugins/database/grid/presentation/grid_page.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/header/field_type_extension.dart';
import 'package:appflowy/plugins/database/tab_bar/desktop/setting_menu.dart';
import 'package:appflowy/plugins/database/tab_bar/tab_bar_view.dart';
import 'package:appflowy/plugins/database/widgets/card/card_bloc.dart';
import 'package:appflowy/plugins/database/widgets/cell/card_cell_style_maps/desktop_board_card_cell_style.dart';
import 'package:appflowy/plugins/database/widgets/row/row_detail.dart';
import 'package:appflowy/shared/conditional_listenable_builder.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/row_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flowy_infra_ui/widget/error_page.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/card/card.dart';
import '../../widgets/cell/card_cell_builder.dart';
import '../application/board_bloc.dart';

import 'toolbar/board_setting_bar.dart';
import 'widgets/board_focus_scope.dart';
import 'widgets/board_hidden_groups.dart';
import 'widgets/board_shortcut_container.dart';

class BoardPageTabBarBuilderImpl extends DatabaseTabBarItemBuilder {
  final _toggleExtension = ToggleExtensionNotifier();

  @override
  Widget content(
    BuildContext context,
    ViewPB view,
    DatabaseController controller,
    bool shrinkWrap,
    String? initialRowId,
  ) =>
      BoardPage(view: view, databaseController: controller);

  @override
  Widget settingBar(BuildContext context, DatabaseController controller) =>
      BoardSettingBar(
        key: _makeValueKey(controller),
        databaseController: controller,
        toggleExtension: _toggleExtension,
      );

  @override
  Widget settingBarExtension(
    BuildContext context,
    DatabaseController controller,
  ) {
    return DatabaseViewSettingExtension(
      key: _makeValueKey(controller),
      viewId: controller.viewId,
      databaseController: controller,
      toggleExtension: _toggleExtension,
    );
  }

  @override
  void dispose() {
    _toggleExtension.dispose();
    super.dispose();
  }

  ValueKey _makeValueKey(DatabaseController controller) =>
      ValueKey(controller.viewId);
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
        databaseController: databaseController,
      )..add(const BoardEvent.initial()),
      child: BlocBuilder<BoardBloc, BoardState>(
        buildWhen: (p, c) => !c.isOpenCard,
        builder: (context, state) => state.map(
          loading: (_) => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          openCard: (_) => const SizedBox.shrink(),
          error: (err) => PlatformExtension.isMobile
              ? FlowyMobileStateContainer.error(
                  emoji: '🛸',
                  title: LocaleKeys.board_mobile_failedToLoad.tr(),
                  errorMsg: err.toString(),
                )
              : FlowyErrorPage.message(
                  err.toString(),
                  howToFix: LocaleKeys.errorDialog_howToFixFallback.tr(),
                ),
          ready: (data) => PlatformExtension.isMobile
              ? const MobileBoardContent()
              : DesktopBoardContent(onEditStateChanged: onEditStateChanged),
        ),
      ),
    );
  }
}

class DesktopBoardContent extends StatefulWidget {
  const DesktopBoardContent({super.key, this.onEditStateChanged});

  final VoidCallback? onEditStateChanged;

  @override
  State<DesktopBoardContent> createState() => _DesktopBoardContentState();
}

class _DesktopBoardContentState extends State<DesktopBoardContent> {
  final ScrollController scrollController = ScrollController();
  final AppFlowyBoardScrollController scrollManager =
      AppFlowyBoardScrollController();

  final config = const AppFlowyBoardConfig(
    groupMargin: EdgeInsets.symmetric(horizontal: 4),
    groupBodyPadding: EdgeInsets.symmetric(horizontal: 4),
    groupFooterPadding: EdgeInsets.fromLTRB(8, 14, 8, 4),
    groupHeaderPadding: EdgeInsets.symmetric(horizontal: 8),
    cardMargin: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    stretchGroupHeight: false,
  );

  late final cellBuilder = CardCellBuilder(
    databaseController: context.read<BoardBloc>().databaseController,
  );

  late final cardFocusNotifier = BoardFocusScope(
    boardController: context.read<BoardBloc>().boardController,
  );

  bool isDragging = false;
  Offset startPos = Offset.zero;
  Offset currentPos = Offset.zero;

  @override
  void dispose() {
    cardFocusNotifier.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BoardSelectorBloc>(
      create: (_) => BoardSelectorBloc(),
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onPanStart: (details) => context
                .read<BoardSelectorBloc>()
                .add(BoardSelectorEvent.startDragging(details.localPosition)),
            onPanUpdate: (details) {
              debugPrint("onPanUpdate: ${details.localPosition}");
              context
                  .read<BoardSelectorBloc>()
                  .add(BoardSelectorEvent.addDrag(details.localPosition));
            },
            onPanEnd: (_) => context
                .read<BoardSelectorBloc>()
                .add(const BoardSelectorEvent.endDragging()),
            child: Stack(
              children: [
                BlocConsumer<BoardBloc, BoardState>(
                  listener: (context, state) {
                    widget.onEditStateChanged?.call();
                    state.maybeWhen(
                      orElse: () {},
                      openCard: (rowMeta) {
                        _openCard(
                          context: context,
                          databaseController:
                              context.read<BoardBloc>().databaseController,
                          rowMeta: rowMeta,
                        );
                      },
                    );
                  },
                  builder: (context, state) {
                    final showCreateGroupButton = context
                            .read<BoardBloc>()
                            .groupingFieldType
                            ?.canCreateNewGroup ??
                        false;
                    return FocusScope(
                      autofocus: true,
                      child: BoardShortcutContainer(
                        focusScope: cardFocusNotifier,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: AppFlowyBoard(
                            boardScrollController: scrollManager,
                            scrollController: scrollController,
                            controller:
                                context.read<BoardBloc>().boardController,
                            groupConstraints:
                                const BoxConstraints.tightFor(width: 256),
                            config: config,
                            leading: HiddenGroupsColumn(
                              margin: config.groupHeaderPadding,
                            ),
                            trailing: showCreateGroupButton
                                ? BoardTrailing(
                                    scrollController: scrollController,
                                  )
                                : const HSpace(40),
                            headerBuilder: (_, groupData) =>
                                BlocProvider<BoardBloc>.value(
                              value: context.read<BoardBloc>(),
                              child: BoardColumnHeader(
                                groupData: groupData,
                                margin: config.groupHeaderPadding,
                              ),
                            ),
                            footerBuilder: (_, groupData) => BlocProvider.value(
                              value: context.read<BoardBloc>(),
                              child: _BoardColumnFooter(
                                columnData: groupData,
                                boardConfig: config,
                                scrollManager: scrollManager,
                              ),
                            ),
                            cardBuilder: (_, column, columnItem) =>
                                BlocProvider.value(
                              key: ValueKey("${column.id}${columnItem.id}"),
                              value: context.read<BoardBloc>(),
                              child: _BoardCard(
                                afGroupData: column,
                                groupItem: columnItem as GroupItem,
                                boardConfig: config,
                                notifier: cardFocusNotifier,
                                cellBuilder: cellBuilder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                BlocBuilder<BoardSelectorBloc, BoardSelectorState>(
                  builder: (context, state) {
                    final isDragging = state.isDragging;

                    if (!isDragging ||
                        state.startPosition == null ||
                        state.endPosition == null) {
                      return const SizedBox.shrink();
                    }

                    final startPos = state.startPosition!;
                    final currentPos = state.endPosition!;

                    return Positioned(
                      left: startPos.dx < currentPos.dx
                          ? startPos.dx
                          : currentPos.dx,
                      top: startPos.dy < currentPos.dy
                          ? startPos.dy
                          : currentPos.dy,
                      width: (startPos.dx < currentPos.dx
                              ? currentPos.dx - startPos.dx
                              : startPos.dx - currentPos.dx)
                          .abs(),
                      height: (startPos.dy < currentPos.dy
                              ? currentPos.dy - startPos.dy
                              : startPos.dy - currentPos.dy)
                          .abs(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoardColumnFooter extends StatefulWidget {
  const _BoardColumnFooter({
    required this.columnData,
    required this.boardConfig,
    required this.scrollManager,
  });

  final AppFlowyGroupData columnData;
  final AppFlowyBoardConfig boardConfig;
  final AppFlowyBoardScrollController scrollManager;

  @override
  State<_BoardColumnFooter> createState() => _BoardColumnFooterState();
}

class _BoardColumnFooterState extends State<_BoardColumnFooter> {
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _focusNode;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (_focusNode.hasFocus &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _focusNode.unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    )..addListener(() {
        if (!_focusNode.hasFocus) {
          setState(() => _isCreating = false);
        }
      });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCreating) {
        _focusNode.requestFocus();
      }
    });
    return Padding(
      padding: widget.boardConfig.groupFooterPadding,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child:
            _isCreating ? _createCardsTextField() : _startCreatingCardsButton(),
      ),
    );
  }

  Widget _createCardsTextField() {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.keyE):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.delete):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.enter):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter):
            DoNothingAndStopPropagationIntent(),
      },
      child: FlowyTextField(
        hintTextConstraints: const BoxConstraints(maxHeight: 36),
        controller: _textController,
        focusNode: _focusNode,
        onSubmitted: (name) {
          context
              .read<BoardBloc>()
              .add(BoardEvent.createBottomRow(widget.columnData.id, name));
          widget.scrollManager.scrollToBottom(widget.columnData.id);
          _textController.clear();
          _focusNode.requestFocus();
        },
      ),
    );
  }

  Widget _startCreatingCardsButton() {
    return FlowyTooltip(
      message: LocaleKeys.board_column_addToColumnBottomTooltip.tr(),
      child: SizedBox(
        height: 36,
        child: FlowyButton(
          leftIcon: FlowySvg(
            FlowySvgs.add_s,
            color: Theme.of(context).hintColor,
          ),
          text: FlowyText.medium(
            LocaleKeys.board_column_createNewCard.tr(),
            color: Theme.of(context).hintColor,
          ),
          onTap: () {
            setState(() => _isCreating = true);
          },
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  _BoardCard({
    required this.afGroupData,
    required this.groupItem,
    required this.boardConfig,
    required this.cellBuilder,
    required this.notifier,
  });

  final AppFlowyGroupData afGroupData;
  final GroupItem groupItem;
  final AppFlowyBoardConfig boardConfig;
  final CardCellBuilder cellBuilder;
  final BoardFocusScope notifier;

  final _cardKey = GlobalKey(debugLabel: 'board_card');

  @override
  Widget build(BuildContext context) {
    final boardBloc = context.read<BoardBloc>();
    return BlocListener<BoardSelectorBloc, BoardSelectorState>(
      listenWhen: (_, current) => current.isDragging,
      listener: (context, state) {
        // Check if any part of the child widget is inside the selection area
        // final isInsideSelectionArea = true;
        // if (isInsideSelectionArea) {
        // final groupData = afGroupData.customData as GroupData;
        // notifier.focus(
        //   [
        //     GroupedRowId(
        //       rowId: groupItem.row.id,
        //       groupId: groupData.group.groupId,
        //     ),
        //   ],
        // );
        // }
      },
      child: BlocBuilder<BoardBloc, BoardState>(
        builder: (context, state) {
          final groupData = afGroupData.customData as GroupData;
          final rowCache = boardBloc.rowCache;
          final rowInfo = rowCache.getRow(groupItem.row.id);

          final databaseController = boardBloc.databaseController;
          final rowMeta = rowInfo?.rowMeta ?? groupItem.row;

          final isEditing = state.maybeMap(
            orElse: () => false,
            ready: (state) => state.editingRow?.rowId == groupItem.row.id,
          );

          return Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowUp):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.keyE):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.delete):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.enter):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter):
                  DoNothingAndStopPropagationIntent(),
            },
            child: ConditionalListenableBuilder<List<GroupedRowId>>(
              valueListenable: notifier,
              buildWhen: (previous, current) {
                final focusItem = GroupedRowId(
                  groupId: groupData.group.groupId,
                  rowId: rowMeta.id,
                );
                final previousContainsFocus = previous.contains(focusItem);
                final currentContainsFocus = current.contains(focusItem);

                return previousContainsFocus != currentContainsFocus;
              },
              builder: (context, focusedItems, child) => Container(
                margin: boardConfig.cardMargin,
                decoration: _makeBoxDecoration(
                  context,
                  groupData.group.groupId,
                  groupItem.id,
                ),
                child: child,
              ),
              child: RowCard(
                key: _cardKey,
                fieldController: databaseController.fieldController,
                rowMeta: rowMeta,
                viewId: boardBloc.viewId,
                rowCache: rowCache,
                groupingFieldId: groupItem.fieldInfo.id,
                isEditing: isEditing,
                cellBuilder: cellBuilder,
                onTap: (context) => _openCard(
                  context: context,
                  databaseController: databaseController,
                  rowMeta: context.read<CardBloc>().state.rowMeta,
                ),
                onShiftTap: (context) => notifier.toggle(
                  GroupedRowId(
                    rowId: groupItem.row.id,
                    groupId: groupData.group.groupId,
                  ),
                ),
                styleConfiguration: RowCardStyleConfiguration(
                  cellStyleMap: desktopBoardCardCellStyleMap(context),
                  hoverStyle: HoverStyle(
                    hoverColor: Theme.of(context).brightness == Brightness.light
                        ? const Color(0x0F1F2329)
                        : const Color(0x0FEFF4FB),
                    foregroundColorOnHover:
                        Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                onStartEditing: () => boardBloc.add(
                  BoardEvent.startEditingRow(
                    GroupedRowId(
                      groupId: groupData.group.groupId,
                      rowId: rowMeta.id,
                    ),
                  ),
                ),
                onEndEditing: () =>
                    boardBloc.add(const BoardEvent.endEditingRow()),
              ),
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _makeBoxDecoration(
    BuildContext context,
    String groupId,
    String rowId,
  ) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      border: Border.fromBorderSide(
        BorderSide(
          color:
              notifier.isFocused(GroupedRowId(rowId: rowId, groupId: groupId))
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFF1F2329).withOpacity(0.12)
                      : const Color(0xFF59647A),
        ),
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 4,
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
}

class BoardTrailing extends StatefulWidget {
  const BoardTrailing({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<BoardTrailing> createState() => _BoardTrailingState();
}

class _BoardTrailingState extends State<BoardTrailing> {
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _focusNode;

  bool isEditing = false;

  void _cancelAddNewGroup() {
    _textController.clear();
    setState(() => isEditing = false);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (_focusNode.hasFocus &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelAddNewGroup();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    )..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // call after every setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEditing) {
        _focusNode.requestFocus();
        widget.scrollController.jumpTo(
          widget.scrollController.position.maxScrollExtent,
        );
      }
    });

    return Container(
      padding: const EdgeInsets.only(left: 8.0, top: 12, right: 40),
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isEditing
            ? SizedBox(
                width: 256,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8.0),
                        child: FlowyIconButton(
                          icon: const FlowySvg(FlowySvgs.close_filled_m),
                          hoverColor: Colors.transparent,
                          onPressed: () => _textController.clear(),
                        ),
                      ),
                      suffixIconConstraints:
                          BoxConstraints.loose(const Size(20, 24)),
                      border: const UnderlineInputBorder(),
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      isDense: true,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                    onSubmitted: (groupName) => context
                        .read<BoardBloc>()
                        .add(BoardEvent.createGroup(groupName)),
                  ),
                ),
              )
            : FlowyTooltip(
                message: LocaleKeys.board_column_createNewColumn.tr(),
                child: FlowyIconButton(
                  width: 26,
                  icon: const FlowySvg(FlowySvgs.add_s),
                  iconColorOnHover: Theme.of(context).colorScheme.onSurface,
                  onPressed: () => setState(() => isEditing = true),
                ),
              ),
      ),
    );
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _cancelAddNewGroup();
    }
  }
}

void _openCard({
  required BuildContext context,
  required DatabaseController databaseController,
  required RowMetaPB rowMeta,
}) {
  final rowController = RowController(
    rowMeta: rowMeta,
    viewId: databaseController.viewId,
    rowCache: databaseController.rowCache,
  );

  FlowyOverlay.show(
    context: context,
    builder: (_) => RowDetailPage(
      databaseController: databaseController,
      rowController: rowController,
    ),
  );
}

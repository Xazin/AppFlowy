import 'package:flutter/material.dart';

import 'package:appflowy/plugins/document/presentation/editor_plugins/actions/mobile_block_action_buttons.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/common.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/multi_image_block_component/multi_image_placeholder.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/multi_image_layouts.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:provider/provider.dart';

const kMultiImagePlaceholderKey = 'multiImagePlaceholderKey';

Node multiImageNode() => Node(
      type: MultiImageBlockKeys.type,
      attributes: {
        MultiImageBlockKeys.images: MultiImageData(images: []).toJson(),
        MultiImageBlockKeys.layout: MultiImageLayout.browser.toIntValue(),
      },
    );

class MultiImageBlockKeys {
  const MultiImageBlockKeys._();

  static const String type = 'multi_image';

  /// The image data for the block, stored as a JSON encoded list of [ImageBlockData].
  ///
  static const String images = 'images';

  /// The layout of the images.
  ///
  /// The value is a MultiImageLayout enum.
  ///
  static const String layout = 'layout';
}

typedef MultiImageBlockComponentMenuBuilder = Widget Function(
  Node node,
  MultiImageBlockComponentState state,
  int selectedIndex,
);

class MultiImageBlockComponentBuilder extends BlockComponentBuilder {
  MultiImageBlockComponentBuilder({
    super.configuration,
    this.showMenu = false,
    this.menuBuilder,
  });

  final bool showMenu;
  final MultiImageBlockComponentMenuBuilder? menuBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return MultiImageBlockComponent(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (_, state) => actionBuilder(blockComponentContext, state),
      showMenu: showMenu,
      menuBuilder: menuBuilder,
    );
  }

  @override
  bool validate(Node node) => node.delta == null && node.children.isEmpty;
}

class MultiImageBlockComponent extends BlockComponentStatefulWidget {
  const MultiImageBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    this.showMenu = false,
    this.menuBuilder,
    super.configuration = const BlockComponentConfiguration(),
    super.actionBuilder,
  });

  final bool showMenu;

  final MultiImageBlockComponentMenuBuilder? menuBuilder;

  @override
  State<MultiImageBlockComponent> createState() =>
      MultiImageBlockComponentState();
}

class MultiImageBlockComponentState extends State<MultiImageBlockComponent>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final multiImageKey = GlobalKey();

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  final showActionsNotifier = ValueNotifier<bool>(false);

  int _selectedIndex = 0;

  bool alwaysShowMenu = false;

  @override
  Widget build(BuildContext context) {
    final data = MultiImageData.fromJson(
      node.attributes[MultiImageBlockKeys.images],
    );

    Widget child;
    if (data.images.isEmpty) {
      final multiImagePlaceholderKey =
          node.extraInfos?[kMultiImagePlaceholderKey];

      child = MultiImagePlaceholder(
        key: multiImagePlaceholderKey is GlobalKey
            ? multiImagePlaceholderKey
            : null,
        node: node,
      );
    } else {
      child = ImageBrowserLayout(
        node: node,
        images: data.images,
        editorState: editorState,
        selectedImage: data.images.first,
        onIndexChanged: (index) => setState(() => _selectedIndex = index),
      );
    }

    if (PlatformExtension.isDesktopOrWeb) {
      child = BlockSelectionContainer(
        node: node,
        delegate: this,
        listenable: editorState.selectionNotifier,
        blockColor: editorState.editorStyle.selectionColor,
        supportTypes: const [BlockSelectionType.block],
        child: Padding(key: multiImageKey, padding: padding, child: child),
      );
    } else {
      child = Padding(key: multiImageKey, padding: padding, child: child);
    }

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        child: child,
      );
    }

    if (PlatformExtension.isDesktopOrWeb) {
      if (widget.showMenu && widget.menuBuilder != null) {
        child = MouseRegion(
          onEnter: (_) => showActionsNotifier.value = true,
          onExit: (_) {
            if (!alwaysShowMenu) {
              showActionsNotifier.value = false;
            }
          },
          hitTestBehavior: HitTestBehavior.opaque,
          opaque: false,
          child: ValueListenableBuilder<bool>(
            valueListenable: showActionsNotifier,
            builder: (context, value, child) {
              return Stack(
                children: [
                  BlockSelectionContainer(
                    node: node,
                    delegate: this,
                    listenable: editorState.selectionNotifier,
                    cursorColor: editorState.editorStyle.cursorColor,
                    selectionColor: editorState.editorStyle.selectionColor,
                    child: child!,
                  ),
                  if (value && data.images.isNotEmpty)
                    widget.menuBuilder!(widget.node, this, _selectedIndex),
                ],
              );
            },
            child: child,
          ),
        );
      }
    } else {
      // show a fixed menu on mobile
      child = MobileBlockActionButtons(
        showThreeDots: false,
        node: node,
        editorState: editorState,
        child: child,
      );
    }

    return child;
  }

  @override
  Position start() => Position(path: widget.node.path);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    final imageBox = multiImageKey.currentContext?.findRenderObject();
    if (imageBox is RenderBox) {
      return Offset.zero & imageBox.size;
    }
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final rects = getRectsInSelection(Selection.collapsed(position));
    return rects.firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) {
      return [];
    }
    final parentBox = context.findRenderObject();
    final imageBox = multiImageKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && imageBox is RenderBox) {
      return [
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      _renderBox!.localToGlobal(offset);
}

/// The data for a multi-image block, primarily used for
/// serializing and deserializing the block's images.
///
class MultiImageData {
  factory MultiImageData.fromJson(List<dynamic> json) {
    final images = json
        .map((e) => ImageBlockData.fromJson(e as Map<String, dynamic>))
        .toList();
    return MultiImageData(images: images);
  }

  MultiImageData({required this.images});

  final List<ImageBlockData> images;

  List<dynamic> toJson() => images.map((e) => e.toJson()).toList();
}

enum MultiImageLayout {
  browser,
  masonry,
  grid;

  int toIntValue() {
    switch (this) {
      case MultiImageLayout.browser:
        return 0;
      case MultiImageLayout.masonry:
        return 1;
      case MultiImageLayout.grid:
        return 2;
    }
  }

  static MultiImageLayout fromIntValue(int value) {
    switch (value) {
      case 0:
        return MultiImageLayout.browser;
      case 1:
        return MultiImageLayout.masonry;
      case 2:
        return MultiImageLayout.grid;
      default:
        throw UnimplementedError();
    }
  }
}

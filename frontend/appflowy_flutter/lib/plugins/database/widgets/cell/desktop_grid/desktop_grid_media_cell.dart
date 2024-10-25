import 'package:flutter/material.dart';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/media_cell_bloc.dart';
import 'package:appflowy/plugins/database/widgets/cell/editable_cell_skeleton/media.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/media_cell_editor.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/mobile_media_cell_editor.dart';
import 'package:appflowy/plugins/database/widgets/media_file_type_ext.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy/shared/af_image.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/media_entities.pb.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

class GridMediaCellSkin extends IEditableMediaCellSkin {
  const GridMediaCellSkin({this.isMobileRowDetail = false});

  final bool isMobileRowDetail;

  @override
  void dispose() {}

  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    PopoverController popoverController,
    MediaCellBloc bloc,
  ) {
    final isMobile = UniversalPlatform.isMobile;

    Widget child = BlocBuilder<MediaCellBloc, MediaCellState>(
      builder: (context, state) {
        final wrapContent = context.read<MediaCellBloc>().wrapContent;
        final List<Widget> children = state.files
            .map(
              (file) => Padding(
                padding: wrapContent
                    ? const EdgeInsets.only(right: 4)
                    : EdgeInsets.zero,
                child: _FilePreviewRender(file: file),
              ),
            )
            .toList();

        if (isMobileRowDetail && state.files.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                LocaleKeys.grid_row_textPlaceholder.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ),
          );
        }

        if (!isMobile && wrapContent) {
          return Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                runSpacing: 4,
                children: children,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SeparatedRow(
                separatorBuilder: () => const HSpace(6),
                children: children,
              ),
            ),
          ),
        );
      },
    );

    if (!isMobile) {
      child = AppFlowyPopover(
        controller: popoverController,
        constraints: const BoxConstraints(
          minWidth: 250,
          maxWidth: 250,
          maxHeight: 400,
        ),
        margin: EdgeInsets.zero,
        triggerActions: PopoverTriggerFlags.none,
        direction: PopoverDirection.bottomWithCenterAligned,
        popupBuilder: (_) => BlocProvider.value(
          value: context.read<MediaCellBloc>(),
          child: const MediaCellEditor(),
        ),
        onClose: () => cellContainerNotifier.isFocus = false,
        child: child,
      );
    } else {
      child = Align(
        alignment: AlignmentDirectional.centerStart,
        child: child,
      );

      if (isMobileRowDetail) {
        child = Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: AlignmentDirectional.centerStart,
          child: child,
        );
      }

      child = InkWell(
        borderRadius:
            isMobileRowDetail ? BorderRadius.circular(12) : BorderRadius.zero,
        onTap: () {
          showMobileBottomSheet(
            context,
            builder: (_) => BlocProvider.value(
              value: context.read<MediaCellBloc>(),
              child: const MobileMediaCellEditor(),
            ),
          );
        },
        hoverColor: Colors.transparent,
        child: child,
      );
    }

    return BlocProvider.value(
      value: bloc,
      child: Builder(builder: (context) => child),
    );
  }
}

class _FilePreviewRender extends StatelessWidget {
  const _FilePreviewRender({required this.file});

  final MediaFilePB file;

  @override
  Widget build(BuildContext context) {
    if (file.fileType != MediaFileTypePB.Image) {
      return Container(
        height: 28,
        width: 28,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AFThemeExtension.of(context).greyHover,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FlowySvg(
          file.fileType.icon,
          color: AFThemeExtension.of(context).textColor,
        ),
      );
    }

    return Container(
      height: 28,
      width: 28,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: AFImage(
        url: file.url,
        uploadType: file.uploadType,
        userProfile: context.read<MediaCellBloc>().state.userProfile,
      ),
    );
  }
}

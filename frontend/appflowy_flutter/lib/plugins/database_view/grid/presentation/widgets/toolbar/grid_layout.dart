import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/database_view/application/layout/layout_bloc.dart';
import 'package:appflowy/plugins/database_view/widgets/database_layout_ext.dart';
import 'package:appflowy/util/platform_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/setting_entities.pb.dart';

import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../layout/sizes.dart';

class DatabaseLayoutList extends StatefulWidget {
  const DatabaseLayoutList({
    super.key,
    required this.viewId,
    required this.currentLayout,
  });

  final String viewId;
  final DatabaseLayoutPB currentLayout;

  @override
  State<StatefulWidget> createState() => _DatabaseLayoutListState();
}

class _DatabaseLayoutListState extends State<DatabaseLayoutList> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DatabaseLayoutBloc(
        viewId: widget.viewId,
        databaseLayout: widget.currentLayout,
      )..add(const DatabaseLayoutEvent.initial()),
      child: BlocBuilder<DatabaseLayoutBloc, DatabaseLayoutState>(
        builder: (context, state) {
          final cells = DatabaseLayoutPB.values
              .map(
                (layout) => DatabaseViewLayoutCell(
                  databaseLayout: layout,
                  isSelected: state.databaseLayout == layout,
                  onTap: (selectedLayout) => context
                      .read<DatabaseLayoutBloc>()
                      .add(DatabaseLayoutEvent.updateLayout(selectedLayout)),
                ),
              )
              .toList();

          return ListView.separated(
            controller: ScrollController(),
            shrinkWrap: true,
            itemCount: cells.length,
            itemBuilder: (BuildContext context, int index) => cells[index],
            separatorBuilder: (BuildContext context, int index) =>
                VSpace(GridSize.typeOptionSeparatorHeight),
            padding: const EdgeInsets.symmetric(vertical: 6.0),
          );
        },
      ),
    );
  }
}

class DatabaseViewLayoutCell extends StatelessWidget {
  const DatabaseViewLayoutCell({
    super.key,
    required this.isSelected,
    required this.databaseLayout,
    required this.onTap,
  });

  final bool isSelected;
  final DatabaseLayoutPB databaseLayout;
  final void Function(DatabaseLayoutPB) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: PlatformExtension.isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: GridSize.popoverItemHeight,
        child: FlowyButton(
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
          text: FlowyText.medium(
            databaseLayout.layoutName(),
            color: AFThemeExtension.of(context).textColor,
          ),
          leftIcon: FlowySvg(
            databaseLayout.icon,
            color: Theme.of(context).iconTheme.color,
          ),
          leftIconSize:
              PlatformExtension.isMobile ? const Size.square(20) : null,
          rightIcon: isSelected
              ? FlowySvg(
                  FlowySvgs.check_s,
                  size:
                      PlatformExtension.isMobile ? const Size.square(20) : null,
                )
              : null,
          onTap: () => onTap(databaseLayout),
        ),
      ),
    );
  }
}

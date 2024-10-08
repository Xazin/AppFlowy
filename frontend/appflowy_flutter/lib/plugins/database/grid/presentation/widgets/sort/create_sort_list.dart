import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/grid/application/simple_text_filter_bloc.dart';
import 'package:appflowy/plugins/database/grid/application/sort/sort_editor_bloc.dart';
import 'package:appflowy/plugins/database/grid/presentation/layout/sizes.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/header/desktop_field_cell.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_list.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/style_widget/text_field.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateDatabaseViewSortList extends StatelessWidget {
  const CreateDatabaseViewSortList({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sortBloc = context.read<SortEditorBloc>();
    return BlocProvider(
      create: (_) => SimpleTextFilterBloc<FieldInfo>(
        values: List.from(sortBloc.state.creatableFields),
        comparator: (val) => val.name,
      ),
      child: BlocListener<SortEditorBloc, SortEditorState>(
        listenWhen: (previous, current) =>
            previous.creatableFields != current.creatableFields,
        listener: (context, state) {
          context.read<SimpleTextFilterBloc<FieldInfo>>().add(
                SimpleTextFilterEvent.receiveNewValues(state.creatableFields),
              );
        },
        child: BlocBuilder<SimpleTextFilterBloc<FieldInfo>,
            SimpleTextFilterState<FieldInfo>>(
          builder: (context, state) {
            final cells = state.values.map((fieldInfo) {
              return GridSortPropertyCell(
                fieldInfo: fieldInfo,
                onTap: () {
                  context
                      .read<SortEditorBloc>()
                      .add(SortEditorEvent.createSort(fieldId: fieldInfo.id));
                  onTap.call();
                },
              );
            }).toList();

            final List<Widget> slivers = [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SortTextFieldDelegate(),
              ),
              SliverToBoxAdapter(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cells.length,
                  itemBuilder: (_, index) => cells[index],
                  separatorBuilder: (_, __) =>
                      VSpace(GridSize.typeOptionSeparatorHeight),
                ),
              ),
            ];
            return CustomScrollView(
              shrinkWrap: true,
              slivers: slivers,
              physics: StyledScrollPhysics(),
            );
          },
        ),
      ),
    );
  }
}

class _SortTextFieldDelegate extends SliverPersistentHeaderDelegate {
  _SortTextFieldDelegate();

  double fixHeight = 36;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      color: Theme.of(context).cardColor,
      height: fixHeight,
      child: FlowyTextField(
        hintText: LocaleKeys.grid_settings_sortBy.tr(),
        onChanged: (text) {
          context
              .read<SimpleTextFilterBloc<FieldInfo>>()
              .add(SimpleTextFilterEvent.updateFilter(text));
        },
      ),
    );
  }

  @override
  double get maxExtent => fixHeight;

  @override
  double get minExtent => fixHeight;

  @override
  bool shouldRebuild(covariant oldDelegate) => false;
}

class GridSortPropertyCell extends StatelessWidget {
  const GridSortPropertyCell({
    super.key,
    required this.fieldInfo,
    required this.onTap,
  });

  final FieldInfo fieldInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GridSize.popoverItemHeight,
      child: FlowyButton(
        hoverColor: AFThemeExtension.of(context).lightGreyHover,
        text: FlowyText(
          fieldInfo.name,
          lineHeight: 1.0,
          color: AFThemeExtension.of(context).textColor,
        ),
        onTap: onTap,
        leftIcon: FieldIcon(
          fieldInfo: fieldInfo,
        ),
      ),
    );
  }
}

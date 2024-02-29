import 'package:flutter/material.dart';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/action_navigation/action_navigation_bloc.dart';
import 'package:appflowy/workspace/application/action_navigation/navigation_action.dart';
import 'package:appflowy/workspace/application/recent/recent_views_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecentViewsList extends StatelessWidget {
  const RecentViewsList({super.key, required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RecentViewsBloc()..add(const RecentViewsEvent.initial()),
      child: BlocBuilder<RecentViewsBloc, RecentViewsState>(
        builder: (context, state) {
          final List<ViewPB> recentViews = state.views.reversed.toList();

          return ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: recentViews.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: FlowyText('Recent history'),
                );
              }

              final view = recentViews[index - 1];
              final icon = view.icon.value.isNotEmpty
                  ? Text(
                      view.icon.value,
                      style: const TextStyle(fontSize: 18.0),
                    )
                  : FlowySvg(view.iconData, size: const Size.square(20));

              return ListTile(
                dense: true,
                title: Row(
                  children: [
                    icon,
                    const HSpace(2),
                    FlowyText(view.name),
                  ],
                ),
                focusColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.5),
                hoverColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.5),
                onTap: () {
                  onSelected();

                  getIt<ActionNavigationBloc>().add(
                    ActionNavigationEvent.performAction(
                      action: NavigationAction(objectId: view.id),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
          );
        },
      ),
    );
  }
}

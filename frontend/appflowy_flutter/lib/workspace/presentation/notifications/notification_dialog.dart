import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/presentation/notifications/notification_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/reminder.pb.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ReminderSortOption {
  descending,
  ascending,
}

extension _ReminderSort on Iterable<ReminderPB> {
  List<ReminderPB> sortByScheduledAt({
    ReminderSortOption reminderSortOption = ReminderSortOption.descending,
  }) =>
      sorted(
        (a, b) => switch (reminderSortOption) {
          ReminderSortOption.descending =>
            b.scheduledAt.compareTo(a.scheduledAt),
          ReminderSortOption.ascending =>
            a.scheduledAt.compareTo(b.scheduledAt),
        },
      );
}

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({
    super.key,
    required this.views,
    required this.mutex,
  });

  final List<ViewPB> views;
  final PopoverMutex mutex;

  @override
  Widget build(BuildContext context) {
    final reminderBloc = getIt<ReminderBloc>();

    return BlocProvider<ReminderBloc>.value(
      value: reminderBloc,
      child: BlocBuilder<ReminderBloc, ReminderState>(
        builder: (context, state) {
          final pastReminders = state.pastReminders.sortByScheduledAt();
          final upcomingReminders = state.upcomingReminders.sortByScheduledAt();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(child: Text('Inbox')),
                    Tab(child: Text('Upcoming')),
                  ],
                ),
                TabBarView(
                  children: [
                    NotificationsView(
                      shownReminders: pastReminders,
                      reminderBloc: reminderBloc,
                      views: views,
                      mutex: mutex,
                    )
                  ],
                ),
                NotificationsView(
                  mutex: mutex,
                  shownReminders: upcomingReminders,
                  reminderBloc: reminderBloc,
                  views: views,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NotificationsView extends StatelessWidget {
  const NotificationsView({
    super.key,
    required this.shownReminders,
    required this.reminderBloc,
    required this.views,
    required this.mutex,
  });

  final List<ReminderPB> shownReminders;
  final ReminderBloc reminderBloc;
  final List<ViewPB> views;
  final PopoverMutex mutex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 10,
                    ),
                    child: FlowyText.semibold(
                      LocaleKeys.notificationHub_title.tr(),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const VSpace(4),
          if (shownReminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: FlowyText.regular(
                  LocaleKeys.notificationHub_empty.tr(),
                ),
              ),
            )
          else
            ...shownReminders.map((reminder) {
              return NotificationItem(
                reminderId: reminder.id,
                key: ValueKey(reminder.id),
                title: reminder.title,
                scheduled: reminder.scheduledAt,
                body: reminder.message,
                isRead: reminder.isRead,
                onReadChanged: (isRead) => reminderBloc.add(
                  ReminderEvent.update(
                    ReminderUpdate(id: reminder.id, isRead: isRead),
                  ),
                ),
                onDelete: () =>
                    reminderBloc.add(ReminderEvent.remove(reminder: reminder)),
                onAction: () {
                  final view = views.firstWhereOrNull(
                    (view) => view.id == reminder.objectId,
                  );

                  if (view == null) {
                    return;
                  }

                  reminderBloc.add(
                    ReminderEvent.pressReminder(reminderId: reminder.id),
                  );

                  mutex.close();
                },
              );
            }),
        ],
      ),
    );
  }
}

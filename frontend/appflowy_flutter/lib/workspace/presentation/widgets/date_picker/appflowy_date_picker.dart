import 'package:flutter/material.dart';

import 'package:appflowy/plugins/database/grid/presentation/widgets/common/type_option_separator.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/header/type_option/date/date_time_format.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/clear_date_button.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/date_picker.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/date_type_option_button.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/end_text_field.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/end_time_button.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/start_text_field.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/date_entities.pbenum.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';

typedef DaySelectedCallback = Function(DateTime, DateTime);
typedef RangeSelectedCallback = Function(DateTime?, DateTime?, DateTime);
typedef IncludeTimeChangedCallback = Function(bool);
typedef TimeChangedCallback = Function(String);

class AppFlowyDatePicker extends StatefulWidget {
  const AppFlowyDatePicker({
    super.key,
    required this.includeTime,
    required this.onIncludeTimeChanged,
    this.rebuildOnDaySelected = true,
    this.enableRanges = true,
    this.isRange = false,
    this.onIsRangeChanged,
    required this.dateFormat,
    required this.timeFormat,
    this.selectedDay,
    this.focusedDay,
    this.firstDay,
    this.lastDay,
    this.startDay,
    this.endDay,
    this.timeStr,
    this.endTimeStr,
    this.timeHintText,
    this.parseEndTimeError,
    this.parseTimeError,
    this.popoverMutex,
    this.onStartTimeSubmitted,
    this.onEndTimeSubmitted,
    this.onDaySelected,
    this.onRangeSelected,
    this.allowFormatChanges = false,
    this.onDateFormatChanged,
    this.onTimeFormatChanged,
    this.onClearDate,
    this.onCalendarCreated,
    this.onPageChanged,
  });

  final bool includeTime;
  final Function(bool) onIncludeTimeChanged;

  final bool enableRanges;
  final bool isRange;
  final Function(bool)? onIsRangeChanged;

  final bool rebuildOnDaySelected;

  final DateFormatPB dateFormat;
  final TimeFormatPB timeFormat;

  final DateTime? selectedDay;
  final DateTime? focusedDay;
  final DateTime? firstDay;
  final DateTime? lastDay;

  /// Start date in selected range
  final DateTime? startDay;

  /// End date in selected range
  final DateTime? endDay;

  final String? timeStr;
  final String? endTimeStr;
  final String? timeHintText;
  final String? parseEndTimeError;
  final String? parseTimeError;
  final PopoverMutex? popoverMutex;

  final TimeChangedCallback? onStartTimeSubmitted;
  final TimeChangedCallback? onEndTimeSubmitted;
  final DaySelectedCallback? onDaySelected;
  final RangeSelectedCallback? onRangeSelected;

  /// If this value is true, then [onTimeFormatChanged] and [onDateFormatChanged]
  /// cannot be null
  ///
  final bool allowFormatChanges;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(DateFormatPB)? onDateFormatChanged;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(TimeFormatPB)? onTimeFormatChanged;

  /// If provided, the ClearDate button will be shown
  /// Otherwise it will be hidden
  ///
  final VoidCallback? onClearDate;

  final void Function(PageController pageController)? onCalendarCreated;

  final void Function(DateTime focusedDay)? onPageChanged;

  @override
  State<AppFlowyDatePicker> createState() => _AppFlowyDatePickerState();
}

class _AppFlowyDatePickerState extends State<AppFlowyDatePicker> {
  @override
  Widget build(BuildContext context) {
    return PlatformExtension.isMobile
        ? _MobileAppFlowyDatePicker(
            includeTime: widget.includeTime,
            onIncludeTimeChanged: widget.onIncludeTimeChanged,
            rebuildOnDaySelected: widget.rebuildOnDaySelected,
            enableRanges: widget.enableRanges,
            isRange: widget.isRange,
            onIsRangeChanged: widget.onIsRangeChanged,
            dateFormat: widget.dateFormat,
            timeFormat: widget.timeFormat,
            selectedDay: widget.selectedDay,
            focusedDay: widget.focusedDay,
            firstDay: widget.firstDay,
            lastDay: widget.lastDay,
            startDay: widget.startDay,
            endDay: widget.endDay,
            timeStr: widget.timeStr,
            endTimeStr: widget.endTimeStr,
            timeHintText: widget.timeHintText,
            parseEndTimeError: widget.parseEndTimeError,
            parseTimeError: widget.parseTimeError,
            popoverMutex: widget.popoverMutex,
            onStartTimeSubmitted: widget.onStartTimeSubmitted,
            onEndTimeSubmitted: widget.onEndTimeSubmitted,
            onDaySelected: widget.onDaySelected,
            onRangeSelected: widget.onRangeSelected,
            allowFormatChanges: widget.allowFormatChanges,
            onDateFormatChanged: widget.onDateFormatChanged,
            onTimeFormatChanged: widget.onTimeFormatChanged,
            onClearDate: widget.onClearDate,
            onCalendarCreated: widget.onCalendarCreated,
            onPageChanged: widget.onPageChanged,
          )
        : _DesktopAppFlowyDatePicker(
            includeTime: widget.includeTime,
            onIncludeTimeChanged: widget.onIncludeTimeChanged,
            rebuildOnDaySelected: widget.rebuildOnDaySelected,
            enableRanges: widget.enableRanges,
            isRange: widget.isRange,
            onIsRangeChanged: widget.onIsRangeChanged,
            dateFormat: widget.dateFormat,
            timeFormat: widget.timeFormat,
            selectedDay: widget.selectedDay,
            focusedDay: widget.focusedDay,
            firstDay: widget.firstDay,
            lastDay: widget.lastDay,
            startDay: widget.startDay,
            endDay: widget.endDay,
            timeStr: widget.timeStr,
            endTimeStr: widget.endTimeStr,
            timeHintText: widget.timeHintText,
            parseEndTimeError: widget.parseEndTimeError,
            parseTimeError: widget.parseTimeError,
            popoverMutex: widget.popoverMutex,
            onStartTimeSubmitted: widget.onStartTimeSubmitted,
            onEndTimeSubmitted: widget.onEndTimeSubmitted,
            onDaySelected: widget.onDaySelected,
            onRangeSelected: widget.onRangeSelected,
            allowFormatChanges: widget.allowFormatChanges,
            onDateFormatChanged: widget.onDateFormatChanged,
            onTimeFormatChanged: widget.onTimeFormatChanged,
            onClearDate: widget.onClearDate,
            onCalendarCreated: widget.onCalendarCreated,
            onPageChanged: widget.onPageChanged,
          );
  }
}

/// Date Picker that is used on Mobile
///
class _MobileAppFlowyDatePicker extends StatefulWidget {
  const _MobileAppFlowyDatePicker({
    required this.includeTime,
    required this.onIncludeTimeChanged,
    this.rebuildOnDaySelected = true,
    this.enableRanges = true,
    this.isRange = false,
    this.onIsRangeChanged,
    required this.dateFormat,
    required this.timeFormat,
    this.selectedDay,
    this.focusedDay,
    this.firstDay,
    this.lastDay,
    this.startDay,
    this.endDay,
    this.timeStr,
    this.endTimeStr,
    this.timeHintText,
    this.parseEndTimeError,
    this.parseTimeError,
    this.popoverMutex,
    this.onStartTimeSubmitted,
    this.onEndTimeSubmitted,
    this.onDaySelected,
    this.onRangeSelected,
    this.allowFormatChanges = false,
    this.onDateFormatChanged,
    this.onTimeFormatChanged,
    this.onClearDate,
    this.onCalendarCreated,
    this.onPageChanged,
  });

  final bool includeTime;
  final Function(bool) onIncludeTimeChanged;

  final bool enableRanges;
  final bool isRange;
  final Function(bool)? onIsRangeChanged;

  final bool rebuildOnDaySelected;

  final DateFormatPB dateFormat;
  final TimeFormatPB timeFormat;

  final DateTime? selectedDay;
  final DateTime? focusedDay;
  final DateTime? firstDay;
  final DateTime? lastDay;

  /// Start date in selected range
  final DateTime? startDay;

  /// End date in selected range
  final DateTime? endDay;

  final String? timeStr;
  final String? endTimeStr;
  final String? timeHintText;
  final String? parseEndTimeError;
  final String? parseTimeError;
  final PopoverMutex? popoverMutex;

  final TimeChangedCallback? onStartTimeSubmitted;
  final TimeChangedCallback? onEndTimeSubmitted;
  final DaySelectedCallback? onDaySelected;
  final RangeSelectedCallback? onRangeSelected;

  /// If this value is true, then [onTimeFormatChanged] and [onDateFormatChanged]
  /// cannot be null
  ///
  final bool allowFormatChanges;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(DateFormatPB)? onDateFormatChanged;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(TimeFormatPB)? onTimeFormatChanged;

  /// If provided, the ClearDate button will be shown
  /// Otherwise it will be hidden
  ///
  final VoidCallback? onClearDate;

  final void Function(PageController pageController)? onCalendarCreated;

  final void Function(DateTime focusedDay)? onPageChanged;

  @override
  State<_MobileAppFlowyDatePicker> createState() =>
      _MobileAppFlowyDatePickerState();
}

class _MobileAppFlowyDatePickerState extends State<_MobileAppFlowyDatePicker> {
  late DateTime? _selectedDay = widget.selectedDay;

  @override
  void didChangeDependencies() {
    _selectedDay = widget.selectedDay;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return DatePicker(
      isRange: widget.isRange,
      onDaySelected: (selectedDay, focusedDay) {
        widget.onDaySelected?.call(selectedDay, focusedDay);

        if (widget.rebuildOnDaySelected) {
          setState(() => _selectedDay = selectedDay);
        }
      },
      onRangeSelected: widget.onRangeSelected,
      selectedDay:
          widget.rebuildOnDaySelected ? _selectedDay : widget.selectedDay,
      firstDay: widget.firstDay,
      lastDay: widget.lastDay,
      startDay: widget.startDay,
      endDay: widget.endDay,
      onCalendarCreated: widget.onCalendarCreated,
      onPageChanged: widget.onPageChanged,
    );
  }
}

/// Date Picker that is used on Desktop
///
class _DesktopAppFlowyDatePicker extends StatefulWidget {
  const _DesktopAppFlowyDatePicker({
    required this.includeTime,
    required this.onIncludeTimeChanged,
    this.rebuildOnDaySelected = true,
    this.enableRanges = true,
    this.isRange = false,
    this.onIsRangeChanged,
    required this.dateFormat,
    required this.timeFormat,
    this.selectedDay,
    this.focusedDay,
    this.firstDay,
    this.lastDay,
    this.startDay,
    this.endDay,
    this.timeStr,
    this.endTimeStr,
    this.timeHintText,
    this.parseEndTimeError,
    this.parseTimeError,
    this.popoverMutex,
    this.onStartTimeSubmitted,
    this.onEndTimeSubmitted,
    this.onDaySelected,
    this.onRangeSelected,
    this.allowFormatChanges = false,
    this.onDateFormatChanged,
    this.onTimeFormatChanged,
    this.onClearDate,
    this.onCalendarCreated,
    this.onPageChanged,
  });

  final bool includeTime;
  final Function(bool) onIncludeTimeChanged;

  final bool enableRanges;
  final bool isRange;
  final Function(bool)? onIsRangeChanged;

  final bool rebuildOnDaySelected;

  final DateFormatPB dateFormat;
  final TimeFormatPB timeFormat;

  final DateTime? selectedDay;
  final DateTime? focusedDay;
  final DateTime? firstDay;
  final DateTime? lastDay;

  /// Start date in selected range
  final DateTime? startDay;

  /// End date in selected range
  final DateTime? endDay;

  final String? timeStr;
  final String? endTimeStr;
  final String? timeHintText;
  final String? parseEndTimeError;
  final String? parseTimeError;
  final PopoverMutex? popoverMutex;

  final TimeChangedCallback? onStartTimeSubmitted;
  final TimeChangedCallback? onEndTimeSubmitted;
  final DaySelectedCallback? onDaySelected;
  final RangeSelectedCallback? onRangeSelected;

  /// If this value is true, then [onTimeFormatChanged] and [onDateFormatChanged]
  /// cannot be null
  ///
  final bool allowFormatChanges;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(DateFormatPB)? onDateFormatChanged;

  /// If [allowFormatChanges] is true, this must be provided
  ///
  final Function(TimeFormatPB)? onTimeFormatChanged;

  /// If provided, the ClearDate button will be shown
  /// Otherwise it will be hidden
  ///
  final VoidCallback? onClearDate;

  final void Function(PageController pageController)? onCalendarCreated;

  final void Function(DateTime focusedDay)? onPageChanged;

  @override
  State<_DesktopAppFlowyDatePicker> createState() =>
      _DesktopAppFlowyDatePickerState();
}

class _DesktopAppFlowyDatePickerState
    extends State<_DesktopAppFlowyDatePicker> {
  late DateTime? _selectedDay = widget.selectedDay;

  @override
  void didChangeDependencies() {
    _selectedDay = widget.selectedDay;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18.0, bottom: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StartTextField(
            includeTime: widget.includeTime,
            timeFormat: widget.timeFormat,
            timeHintText: widget.timeHintText,
            parseEndTimeError: widget.parseEndTimeError,
            parseTimeError: widget.parseTimeError,
            timeStr: widget.timeStr,
            popoverMutex: widget.popoverMutex,
            onSubmitted: widget.onStartTimeSubmitted,
          ),
          EndTextField(
            includeTime: widget.includeTime,
            timeFormat: widget.timeFormat,
            isRange: widget.isRange,
            endTimeStr: widget.endTimeStr,
            popoverMutex: widget.popoverMutex,
            onSubmitted: widget.onEndTimeSubmitted,
          ),
          DatePicker(
            isRange: widget.isRange,
            onDaySelected: (selectedDay, focusedDay) {
              widget.onDaySelected?.call(selectedDay, focusedDay);

              if (widget.rebuildOnDaySelected) {
                setState(() => _selectedDay = selectedDay);
              }
            },
            onRangeSelected: widget.onRangeSelected,
            selectedDay: _selectedDay,
            firstDay: widget.firstDay,
            lastDay: widget.lastDay,
            startDay: widget.startDay,
            endDay: widget.endDay,
            onCalendarCreated: widget.onCalendarCreated,
            onPageChanged: widget.onPageChanged,
          ),
          const TypeOptionSeparator(spacing: 12.0),
          if (widget.enableRanges && widget.onIsRangeChanged != null) ...[
            EndTimeButton(
              isRange: widget.isRange,
              onChanged: widget.onIsRangeChanged!,
            ),
            const VSpace(4.0),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: IncludeTimeButton(
              value: widget.includeTime,
              onChanged: widget.onIncludeTimeChanged,
            ),
          ),
          if (widget.onClearDate != null ||
              (widget.allowFormatChanges &&
                  widget.onDateFormatChanged != null &&
                  widget.onTimeFormatChanged != null))
            // Only show if either of the options are below it
            const TypeOptionSeparator(spacing: 8.0),
          if (widget.allowFormatChanges &&
              widget.onDateFormatChanged != null &&
              widget.onTimeFormatChanged != null)
            DateTypeOptionButton(
              popoverMutex: widget.popoverMutex,
              dateFormat: widget.dateFormat,
              timeFormat: widget.timeFormat,
              onDateFormatChanged: widget.onDateFormatChanged!,
              onTimeFormatChanged: widget.onTimeFormatChanged!,
            ),
          if (widget.onClearDate != null) ...[
            const VSpace(4.0),
            ClearDateButton(onClearDate: widget.onClearDate!),
          ],
        ],
      ),
    );
  }
}

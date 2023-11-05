import 'package:appflowy/plugins/database_view/application/cell/cell_controller_builder.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pb.dart';
import 'package:flutter/material.dart';

import '../../application/cell/cell_service.dart';
import 'cells/card_cell.dart';
import 'cells/checkbox_card_cell.dart';
import 'cells/checklist_card_cell.dart';
import 'cells/date_card_cell.dart';
import 'cells/number_card_cell.dart';
import 'cells/select_option_card_cell.dart';
import 'cells/text_card_cell.dart';
import 'cells/timestamp_card_cell.dart';
import 'cells/url_card_cell.dart';

// T represents as the Generic card data
class CardCellBuilder<CustomCardData> {
  final CellMemCache cellCache;
  final Map<FieldType, CardCellStyle>? styles;

  CardCellBuilder(this.cellCache, {this.styles});

  Widget buildCell({
    CustomCardData? cardData,
    required DatabaseCellContext cellContext,
    EditableCardNotifier? cellNotifier,
    RowCardRenderHook<CustomCardData>? renderHook,
  }) {
    final cellControllerBuilder = CellControllerBuilder(
      cellContext: cellContext,
      cellCache: cellCache,
    );

    final key = cellContext.key();
    final style = styles?[cellContext.fieldType];
    switch (cellContext.fieldType) {
      case FieldType.Checkbox:
        return CheckboxCardCell(
          key: key,
          cellControllerBuilder: cellControllerBuilder,
        );
      case FieldType.DateTime:
        return DateCardCell<CustomCardData>(
          key: key,
          renderHook: renderHook?.renderHook[FieldType.DateTime],
          cellControllerBuilder: cellControllerBuilder,
        );
      case FieldType.LastEditedTime:
      case FieldType.CreatedTime:
        return TimestampCardCell<CustomCardData>(
          key: key,
          renderHook: renderHook?.renderHook[cellContext.fieldType],
          cellControllerBuilder: cellControllerBuilder,
        );
      case FieldType.SingleSelect:
      case FieldType.MultiSelect:
        return SelectOptionCardCell<CustomCardData>(
          key: key,
          renderHook: renderHook?.renderHook[cellContext.fieldType],
          cellControllerBuilder: cellControllerBuilder,
          cardData: cardData,
          editableNotifier: cellNotifier,
        );

      case FieldType.Checklist:
        return ChecklistCardCell(
          key: key,
          cellControllerBuilder: cellControllerBuilder,
        );
      case FieldType.Number:
        return NumberCardCell<CustomCardData>(
          key: key,
          renderHook: renderHook?.renderHook[FieldType.Number],
          style: isStyleOrNull<NumberCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
        );
      case FieldType.RichText:
        return TextCardCell<CustomCardData>(
          key: key,
          renderHook: renderHook?.renderHook[FieldType.RichText],
          cellControllerBuilder: cellControllerBuilder,
          editableNotifier: cellNotifier,
          cardData: cardData,
          style: isStyleOrNull<TextCardCellStyle>(style),
          showEmoji: cellContext.fieldInfo.isPrimary,
          emoji: cellContext.emoji,
        );
      case FieldType.URL:
        return URLCardCell<CustomCardData>(
          key: key,
          style: isStyleOrNull<URLCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
        );
    }
    throw UnimplementedError;
  }
}

import {
  RowId,
  YDatabaseField,
  YDatabaseFields,
  YDatabaseRow,
  YDatabaseSorts,
  YDoc,
  YjsDatabaseKey,
  YjsEditorKey,
} from '@/application/types';
import { FieldType, SortCondition } from '@/application/database-yjs/database.type';
import { parseChecklistData, parseSelectOptionCellData } from '@/application/database-yjs/fields';
import { Row } from '@/application/database-yjs/selector';
import { orderBy } from 'lodash-es';

export function sortBy (rows: Row[], sorts: YDatabaseSorts, fields: YDatabaseFields, rowMetas: Record<RowId, YDoc>) {
  const sortArray = sorts.toArray();

  if (sortArray.length === 0 || Object.keys(rowMetas).length === 0 || fields.size === 0) return rows;
  const iteratees = sortArray.map((sort) => {
    return (row: { id: string }) => {
      const fieldId = sort.get(YjsDatabaseKey.field_id);
      const field = fields.get(fieldId);
      const fieldType = Number(field.get(YjsDatabaseKey.type));

      const rowId = row.id;
      const rowMeta = rowMetas[rowId];

      const defaultData = parseCellDataForSort(field, '');

      const meta = rowMeta?.getMap(YjsEditorKey.data_section).get(YjsEditorKey.database_row) as YDatabaseRow;

      if (!meta) return defaultData;
      if (fieldType === FieldType.LastEditedTime) {
        return meta.get(YjsDatabaseKey.last_modified);
      }

      if (fieldType === FieldType.CreatedTime) {
        return meta.get(YjsDatabaseKey.created_at);
      }

      const cells = meta.get(YjsDatabaseKey.cells);
      const cell = cells.get(fieldId);

      if (!cell) return defaultData;

      return parseCellDataForSort(field, cell.get(YjsDatabaseKey.data) ?? '');
    };
  });
  const orders = sortArray.map((sort) => {
    const condition = Number(sort.get(YjsDatabaseKey.condition));

    if (condition === SortCondition.Descending) return 'desc';
    return 'asc';
  });

  return orderBy(rows, iteratees, orders);
}

export function parseCellDataForSort (field: YDatabaseField, data: string | boolean | number | object) {
  const fieldType = Number(field.get(YjsDatabaseKey.type));

  switch (fieldType) {
    case FieldType.RichText:
    case FieldType.URL:
      return data ? data : '\uFFFF';
    case FieldType.Number:
      return data === 'string' && !isNaN(parseInt(data)) ? parseInt(data) : data;
    case FieldType.Checkbox:
      return data === 'Yes';
    case FieldType.SingleSelect:
    case FieldType.MultiSelect:
      return parseSelectOptionCellData(field, data as string);
    case FieldType.Checklist:
      return parseChecklistData(data as string)?.percentage ?? 0;
    case FieldType.DateTime:
      return Number(data);
    case FieldType.Relation:
      return '';
  }
}

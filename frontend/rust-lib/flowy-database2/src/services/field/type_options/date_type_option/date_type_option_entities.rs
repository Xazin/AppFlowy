#![allow(clippy::upper_case_acronyms)]

use bytes::Bytes;
use collab::core::any_map::AnyMapExtension;
use collab_database::rows::{new_cell_builder, Cell};
use serde::de::Visitor;
use serde::{Deserialize, Serialize};
use std::fmt;
use strum_macros::EnumIter;

use flowy_error::{internal_error, FlowyResult};

use crate::entities::{DateCellDataPB, FieldType, ReminderOptionPB};
use crate::services::cell::{
  CellProtobufBlobParser, DecodedCellData, FromCellChangeset, FromCellString, ToCellChangeset,
};
use crate::services::field::{TypeOptionCellData, CELL_DATA};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct DateCellChangeset {
  pub date: Option<i64>,
  pub time: Option<String>,
  pub end_date: Option<i64>,
  pub end_time: Option<String>,
  pub include_time: Option<bool>,
  pub is_range: Option<bool>,
  pub clear_flag: Option<bool>,
  pub reminder_id: Option<String>,
  pub reminder_option: Option<ReminderOptionPB>,
}

impl FromCellChangeset for DateCellChangeset {
  fn from_changeset(changeset: String) -> FlowyResult<Self>
  where
    Self: Sized,
  {
    serde_json::from_str::<DateCellChangeset>(&changeset).map_err(internal_error)
  }
}

impl ToCellChangeset for DateCellChangeset {
  fn to_cell_changeset_str(&self) -> String {
    serde_json::to_string(self).unwrap_or_default()
  }
}

#[derive(Default, Clone, Debug, Serialize)]
pub struct DateCellData {
  pub timestamp: Option<i64>,
  pub end_timestamp: Option<i64>,
  #[serde(default)]
  pub include_time: bool,
  #[serde(default)]
  pub is_range: bool,
  pub reminder_id: String,
  #[serde(default)]
  pub reminder_option: ReminderOptionPB,
}

impl DateCellData {
  pub fn new(
    timestamp: i64,
    include_time: bool,
    is_range: bool,
    reminder_id: String,
    reminder_option: ReminderOptionPB,
  ) -> Self {
    Self {
      timestamp: Some(timestamp),
      end_timestamp: None,
      include_time,
      is_range,
      reminder_id,
      reminder_option,
    }
  }
}

impl TypeOptionCellData for DateCellData {
  fn is_cell_empty(&self) -> bool {
    self.timestamp.is_none()
  }
}

impl From<&Cell> for DateCellData {
  fn from(cell: &Cell) -> Self {
    let timestamp = cell
      .get_str_value(CELL_DATA)
      .and_then(|data| data.parse::<i64>().ok());
    let end_timestamp = cell
      .get_str_value("end_timestamp")
      .and_then(|data| data.parse::<i64>().ok());
    let include_time = cell.get_bool_value("include_time").unwrap_or_default();
    let is_range = cell.get_bool_value("is_range").unwrap_or_default();
    let reminder_id = cell.get_str_value("reminder_id").unwrap_or_default();
    let reminder_option_raw = cell.get_str_value("reminder_option").unwrap_or_default();
    let reminder_option =
      serde_json::from_str(&reminder_option_raw).unwrap_or(ReminderOptionPB::None);

    Self {
      timestamp,
      end_timestamp,
      include_time,
      is_range,
      reminder_id,
      reminder_option,
    }
  }
}

impl From<&DateCellDataPB> for DateCellData {
  fn from(data: &DateCellDataPB) -> Self {
    Self {
      timestamp: Some(data.timestamp),
      end_timestamp: Some(data.end_timestamp),
      include_time: data.include_time,
      is_range: data.is_range,
      reminder_id: data.reminder_id.to_owned(),
      reminder_option: data.reminder_option,
    }
  }
}

impl From<&DateCellData> for Cell {
  fn from(cell_data: &DateCellData) -> Self {
    let timestamp_string = match cell_data.timestamp {
      Some(timestamp) => timestamp.to_string(),
      None => "".to_owned(),
    };
    let end_timestamp_string = match cell_data.end_timestamp {
      Some(timestamp) => timestamp.to_string(),
      None => "".to_owned(),
    };
    // Most of the case, don't use these keys in other places. Otherwise, we should define
    // constants for them.
    new_cell_builder(FieldType::DateTime)
      .insert_str_value(CELL_DATA, timestamp_string)
      .insert_str_value("end_timestamp", end_timestamp_string)
      .insert_bool_value("include_time", cell_data.include_time)
      .insert_bool_value("is_range", cell_data.is_range)
      .insert_str_value("reminder_id", cell_data.reminder_id.to_owned())
      .insert_str_value(
        "reminder_option",
        serde_json::to_string(&cell_data.reminder_option).unwrap_or_default(),
      )
      .build()
  }
}

impl<'de> serde::Deserialize<'de> for DateCellData {
  fn deserialize<D>(deserializer: D) -> core::result::Result<Self, D::Error>
  where
    D: serde::Deserializer<'de>,
  {
    struct DateCellVisitor();

    impl<'de> Visitor<'de> for DateCellVisitor {
      type Value = DateCellData;

      fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str(
          "DateCellData with type: str containing either an integer timestamp or the JSON representation",
        )
      }

      fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E>
      where
        E: serde::de::Error,
      {
        Ok(DateCellData {
          timestamp: Some(value),
          end_timestamp: None,
          include_time: false,
          is_range: false,
          reminder_id: String::new(),
          reminder_option: ReminderOptionPB::None,
        })
      }

      fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
      where
        E: serde::de::Error,
      {
        self.visit_i64(value as i64)
      }

      fn visit_map<M>(self, mut map: M) -> Result<Self::Value, M::Error>
      where
        M: serde::de::MapAccess<'de>,
      {
        let mut timestamp: Option<i64> = None;
        let mut end_timestamp: Option<i64> = None;
        let mut include_time: Option<bool> = None;
        let mut is_range: Option<bool> = None;
        let mut reminder_id: Option<String> = None;
        let mut reminder_option: Option<ReminderOptionPB> = None;

        while let Some(key) = map.next_key()? {
          match key {
            "timestamp" => {
              timestamp = map.next_value()?;
            },
            "end_timestamp" => {
              end_timestamp = map.next_value()?;
            },
            "include_time" => {
              include_time = map.next_value()?;
            },
            "is_range" => {
              is_range = map.next_value()?;
            },
            "reminder_id" => {
              reminder_id = map.next_value()?;
            },
            "reminder_option" => {
              reminder_option = map.next_value()?;
            },
            _ => {},
          }
        }

        let include_time = include_time.unwrap_or_default();
        let is_range = is_range.unwrap_or_default();
        let reminder_id = reminder_id.unwrap_or_default();
        let reminder_option = reminder_option.unwrap_or_default();

        Ok(DateCellData {
          timestamp,
          end_timestamp,
          include_time,
          is_range,
          reminder_id,
          reminder_option,
        })
      }
    }

    deserializer.deserialize_any(DateCellVisitor())
  }
}

impl FromCellString for DateCellData {
  fn from_cell_str(s: &str) -> FlowyResult<Self>
  where
    Self: Sized,
  {
    let result: DateCellData = serde_json::from_str(s).unwrap();
    Ok(result)
  }
}

impl ToString for DateCellData {
  fn to_string(&self) -> String {
    serde_json::to_string(self).unwrap()
  }
}

#[derive(Clone, Debug, Copy, EnumIter, Serialize, Deserialize, Default)]
pub enum DateFormat {
  Local = 0,
  US = 1,
  ISO = 2,
  #[default]
  Friendly = 3,
  DayMonthYear = 4,
}

impl std::convert::From<i64> for DateFormat {
  fn from(value: i64) -> Self {
    match value {
      0 => DateFormat::Local,
      1 => DateFormat::US,
      2 => DateFormat::ISO,
      3 => DateFormat::Friendly,
      4 => DateFormat::DayMonthYear,
      _ => {
        tracing::error!("Unsupported date format, fallback to friendly");
        DateFormat::Friendly
      },
    }
  }
}

impl DateFormat {
  pub fn value(&self) -> i64 {
    *self as i64
  }
  // https://docs.rs/chrono/0.4.19/chrono/format/strftime/index.html
  pub fn format_str(&self) -> &'static str {
    match self {
      DateFormat::Local => "%m/%d/%Y",
      DateFormat::US => "%Y/%m/%d",
      DateFormat::ISO => "%Y-%m-%d",
      DateFormat::Friendly => "%b %d, %Y",
      DateFormat::DayMonthYear => "%d/%m/%Y",
    }
  }
}

#[derive(Clone, Copy, PartialEq, Eq, EnumIter, Debug, Hash, Serialize, Deserialize, Default)]
pub enum TimeFormat {
  TwelveHour = 0,
  #[default]
  TwentyFourHour = 1,
}

impl std::convert::From<i64> for TimeFormat {
  fn from(value: i64) -> Self {
    match value {
      0 => TimeFormat::TwelveHour,
      1 => TimeFormat::TwentyFourHour,
      _ => {
        tracing::error!("Unsupported time format, fallback to TwentyFourHour");
        TimeFormat::TwentyFourHour
      },
    }
  }
}

impl TimeFormat {
  pub fn value(&self) -> i64 {
    *self as i64
  }

  // https://docs.rs/chrono/0.4.19/chrono/format/strftime/index.html
  pub fn format_str(&self) -> &'static str {
    match self {
      TimeFormat::TwelveHour => "%I:%M %p",
      TimeFormat::TwentyFourHour => "%R",
    }
  }
}

impl DecodedCellData for DateCellDataPB {
  type Object = DateCellDataPB;

  fn is_empty(&self) -> bool {
    self.date.is_empty()
  }
}

pub struct DateCellDataParser();
impl CellProtobufBlobParser for DateCellDataParser {
  type Object = DateCellDataPB;

  fn parser(bytes: &Bytes) -> FlowyResult<Self::Object> {
    DateCellDataPB::try_from(bytes.as_ref()).map_err(internal_error)
  }
}

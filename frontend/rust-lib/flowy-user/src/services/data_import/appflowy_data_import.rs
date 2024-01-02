use crate::migrations::session_migration::migrate_session_with_user_uuid;

use crate::services::data_import::importer::load_collab_by_oid;
use crate::services::db::UserDBPath;
use crate::services::entities::{Session, UserPaths};
use crate::services::user_awareness::awareness_oid_from_user_uuid;
use anyhow::anyhow;
use collab::core::collab::{CollabDocState, MutexCollab};
use collab::core::origin::CollabOrigin;
use collab::preclude::Collab;
use collab_database::database::{
  is_database_collab, mut_database_views_with_collab, reset_inline_view_id,
};
use collab_database::rows::{database_row_document_id_from_row_id, mut_row_with_collab, RowId};
use collab_database::user::DatabaseViewTrackerList;
use collab_document::document_data::default_document_collab_data;
use collab_entity::CollabType;
use collab_folder::{Folder, UserId, View, ViewIdentifier, ViewLayout};
use collab_integrate::{PersistenceError, RocksCollabDB, YrsDocAction};
use flowy_error::{internal_error, FlowyError};
use flowy_folder_deps::cloud::gen_view_id;
use flowy_folder_deps::entities::ImportData;
use flowy_folder_deps::folder_builder::{ParentChildViews, ViewBuilder};
use flowy_sqlite::kv::StorePreferences;
use flowy_user_deps::cloud::{UserCloudService, UserCollabParams};
use flowy_user_deps::entities::Authenticator;
use parking_lot::{Mutex, RwLock};
use std::collections::{HashMap, HashSet};
use std::ops::{Deref, DerefMut};
use std::sync::Arc;
use tracing::{debug, event, info, instrument};

pub(crate) struct ImportContext {
  pub imported_session: Session,
  pub imported_collab_db: Arc<RocksCollabDB>,
  pub container_name: Option<String>,
}

impl ImportContext {
  pub fn with_container_name(mut self, container_name: Option<String>) -> Self {
    self.container_name = container_name;
    self
  }
}

pub(crate) fn get_appflowy_data_folder_import_context(path: &str) -> anyhow::Result<ImportContext> {
  let user_paths = UserPaths::new(path.to_string());
  let other_store_preferences = Arc::new(StorePreferences::new(path)?);
  migrate_session_with_user_uuid("appflowy_session_cache", &other_store_preferences);
  let session = other_store_preferences
    .get_object::<Session>("appflowy_session_cache")
    .ok_or(anyhow!(
      "Can't find the session cache in the appflowy data folder at path: {}",
      path
    ))?;

  let collab_db_path = user_paths.collab_db_path(session.user_id);
  let collab_db = Arc::new(RocksCollabDB::open(collab_db_path)?);
  Ok(ImportContext {
    imported_session: session,
    imported_collab_db: collab_db,
    container_name: None,
  })
}

/// This path refers to the directory where AppFlowy stores its data. The directory structure is as follows:
/// root folder:
///   - cache.db
///   - log (log files with unique identifiers)
///   - 2761499 (other relevant files or directories, identified by unique numbers)

pub(crate) fn import_appflowy_data_folder(
  session: &Session,
  workspace_id: &str,
  collab_db: &Arc<RocksCollabDB>,
  import_context: ImportContext,
) -> anyhow::Result<ImportData> {
  let imported_session = import_context.imported_session;
  let imported_collab_db = import_context.imported_collab_db;
  let container_name = import_context.container_name;
  let imported_collab_read_txn = imported_collab_db.read_txn();

  let mut database_view_ids_by_database_id: HashMap<String, Vec<String>> = HashMap::new();
  let row_object_ids = Mutex::new(HashSet::new());
  let document_object_ids = Mutex::new(HashSet::new());
  let database_object_ids = Mutex::new(HashSet::new());
  let import_container_view_id = match &container_name {
    None => workspace_id.to_string(),
    Some(_) => gen_view_id().to_string(),
  };

  let views = collab_db.with_write_txn(|collab_write_txn| {
    // use the old_to_new_id_map to keep track of the other collab object id and the new collab object id
    let old_to_new_id_map = Arc::new(Mutex::new(OldToNewIdMap::new()));
    let mut all_imported_object_ids = imported_collab_read_txn
      .get_all_docs()
      .map(|iter| iter.collect::<Vec<String>>())
      .unwrap_or_default();

    // when doing import, we don't want to import the user workspace, database view tracker and the user awareness
    all_imported_object_ids.retain(|id| id != &imported_session.user_workspace.id);
    all_imported_object_ids
      .retain(|id| id != &imported_session.user_workspace.database_view_tracker_id);
    all_imported_object_ids
      .retain(|id| id != &awareness_oid_from_user_uuid(&imported_session.user_uuid).to_string());

    // import database view tracker
    migrate_database_view_tracker(
      &mut old_to_new_id_map.lock(),
      &imported_session,
      &imported_collab_read_txn,
      &mut database_view_ids_by_database_id,
      &database_object_ids,
    )?;

    // remove the database view ids from the object ids. Because there are no collab object for the database view
    let database_view_ids: Vec<String> = database_view_ids_by_database_id
      .values()
      .flatten()
      .cloned()
      .collect();
    all_imported_object_ids.retain(|id| !database_view_ids.contains(id));

    // load other collab objects
    let imported_collab_by_oid = load_collab_by_oid(
      imported_session.user_id,
      &imported_collab_read_txn,
      &all_imported_object_ids,
    );
    // import the database
    migrate_databases(
      &old_to_new_id_map,
      session,
      collab_write_txn,
      &mut all_imported_object_ids,
      &imported_collab_by_oid,
      &row_object_ids,
    )?;

    // the object ids now only contains the document collab object ids
    for object_id in &all_imported_object_ids {
      if let Some(imported_collab) = imported_collab_by_oid.get(object_id) {
        let new_object_id = old_to_new_id_map.lock().renew_id(object_id);
        document_object_ids.lock().insert(new_object_id.clone());
        debug!("import from: {}, to: {}", object_id, new_object_id,);
        import_collab_object(
          imported_collab,
          session.user_id,
          &new_object_id,
          collab_write_txn,
        );
      }
    }

    // create a root view that contains all the views
    let child_views = import_workspace_views(
      &import_container_view_id,
      &mut old_to_new_id_map.lock(),
      &imported_session,
      &imported_collab_read_txn,
    )?;

    match container_name {
      None => Ok(child_views),
      Some(container_name) => {
        let name = if container_name.is_empty() {
          format!(
            "import_{}",
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
          )
        } else {
          container_name
        };

        // create the content for the container view
        let import_container_doc_state = default_document_collab_data(&import_container_view_id)
          .doc_state
          .to_vec();
        import_collab_object_with_doc_state(
          import_container_doc_state,
          session.user_id,
          &import_container_view_id,
          collab_write_txn,
        )?;

        document_object_ids
          .lock()
          .insert(import_container_view_id.clone());
        let import_container_view =
          ViewBuilder::new(session.user_id, session.user_workspace.id.clone())
            .with_view_id(import_container_view_id)
            .with_layout(ViewLayout::Document)
            .with_name(name)
            .with_child_views(child_views)
            .build();

        Ok(vec![import_container_view])
      },
    }
  })?;
  Ok(ImportData::AppFlowyDataFolder {
    views,
    database_view_ids_by_database_id,
    row_object_ids: row_object_ids.into_inner().into_iter().collect(),
    database_object_ids: database_object_ids.into_inner().into_iter().collect(),
    document_object_ids: document_object_ids.into_inner().into_iter().collect(),
  })
}

fn migrate_database_view_tracker<'a, W>(
  old_to_new_id_map: &mut OldToNewIdMap,
  other_session: &Session,
  other_collab_read_txn: &'a W,
  database_view_ids_by_database_id: &mut HashMap<String, Vec<String>>,
  database_object_ids: &Mutex<HashSet<String>>,
) -> Result<(), PersistenceError>
where
  W: YrsDocAction<'a>,
  PersistenceError: From<W::Error>,
{
  let database_view_tracker_collab = Collab::new(
    other_session.user_id,
    &other_session.user_workspace.database_view_tracker_id,
    "phantom",
    vec![],
  );
  database_view_tracker_collab.with_origin_transact_mut(|txn| {
    other_collab_read_txn.load_doc_with_txn(
      other_session.user_id,
      &other_session.user_workspace.database_view_tracker_id,
      txn,
    )
  })?;

  let array = DatabaseViewTrackerList::from_collab(&database_view_tracker_collab);
  for database_view_tracker in array.get_all_database_tracker() {
    database_view_ids_by_database_id.insert(
      old_to_new_id_map.renew_id(&database_view_tracker.database_id),
      database_view_tracker
        .linked_views
        .into_iter()
        .map(|view_id| old_to_new_id_map.renew_id(&view_id))
        .collect(),
    );
  }
  database_object_ids.lock().extend(
    database_view_ids_by_database_id
      .keys()
      .cloned()
      .collect::<Vec<String>>(),
  );
  Ok(())
}

fn migrate_databases<'a, W>(
  old_to_new_id_map: &Arc<Mutex<OldToNewIdMap>>,
  session: &Session,
  collab_write_txn: &'a W,
  imported_object_ids: &mut Vec<String>,
  imported_collab_by_oid: &HashMap<String, Collab>,
  row_object_ids: &Mutex<HashSet<String>>,
) -> Result<(), PersistenceError>
where
  W: YrsDocAction<'a>,
  PersistenceError: From<W::Error>,
{
  // Migrate databases
  let mut database_object_ids = vec![];
  let imported_database_row_object_ids = RwLock::new(HashSet::new());

  for object_id in &mut *imported_object_ids {
    if let Some(database_collab) = imported_collab_by_oid.get(object_id) {
      if !is_database_collab(database_collab) {
        continue;
      }

      database_object_ids.push(object_id.clone());
      reset_inline_view_id(database_collab, |old_inline_view_id| {
        old_to_new_id_map.lock().renew_id(&old_inline_view_id)
      });

      mut_database_views_with_collab(database_collab, |database_view| {
        let new_view_id = old_to_new_id_map.lock().renew_id(&database_view.id);
        let new_database_id = old_to_new_id_map
          .lock()
          .renew_id(&database_view.database_id);

        database_view.id = new_view_id;
        database_view.database_id = new_database_id;
        database_view.row_orders.iter_mut().for_each(|row_order| {
          let old_row_id = String::from(row_order.id.clone());
          let old_row_document_id = database_row_document_id_from_row_id(&old_row_id);
          let new_row_id = old_to_new_id_map.lock().renew_id(&old_row_id);
          let new_row_document_id = database_row_document_id_from_row_id(&new_row_id);

          old_to_new_id_map
            .lock()
            .insert(old_row_document_id.clone(), new_row_document_id);

          row_order.id = RowId::from(new_row_id);
          imported_database_row_object_ids.write().insert(old_row_id);
        });

        // collect the ids
        let new_row_ids = database_view
          .row_orders
          .iter()
          .map(|order| order.id.clone().into_inner())
          .collect::<Vec<String>>();

        row_object_ids.lock().extend(new_row_ids);
      });

      let new_object_id = old_to_new_id_map.lock().renew_id(object_id);
      debug!(
        "migrate database from: {}, to: {}",
        object_id, new_object_id,
      );
      import_collab_object(
        database_collab,
        session.user_id,
        &new_object_id,
        collab_write_txn,
      );
    }
  }
  let imported_database_row_object_ids = imported_database_row_object_ids.read();

  // remove the database object ids from the object ids
  imported_object_ids.retain(|id| !database_object_ids.contains(id));
  imported_object_ids.retain(|id| !imported_database_row_object_ids.contains(id));

  for imported_row_id in &*imported_database_row_object_ids {
    if let Some(imported_collab) = imported_collab_by_oid.get(imported_row_id) {
      let new_row_id = old_to_new_id_map.lock().renew_id(imported_row_id);
      info!(
        "import database row from: {}, to: {}",
        imported_row_id, new_row_id,
      );
      mut_row_with_collab(imported_collab, |row_update| {
        row_update.set_row_id(RowId::from(new_row_id.clone()));
      });
      import_collab_object(
        imported_collab,
        session.user_id,
        &new_row_id,
        collab_write_txn,
      );
    }

    let imported_row_document_id = database_row_document_id_from_row_id(imported_row_id);
    if imported_collab_by_oid
      .get(&imported_row_document_id)
      .is_some()
    {
      let new_row_document_id = old_to_new_id_map.lock().renew_id(&imported_row_document_id);
      info!(
        "map row document from: {}, to: {}",
        imported_row_document_id, new_row_document_id,
      );
    }
  }
  Ok(())
}

fn import_collab_object<'a, W>(collab: &Collab, new_uid: i64, new_object_id: &str, w_txn: &'a W)
where
  W: YrsDocAction<'a>,
  PersistenceError: From<W::Error>,
{
  let txn = collab.transact();
  if let Err(err) = w_txn.create_new_doc(new_uid, &new_object_id, &txn) {
    tracing::error!("import collab:{} failed: {:?}", new_object_id, err);
  }
}

fn import_collab_object_with_doc_state<'a, W>(
  doc_state: CollabDocState,
  new_uid: i64,
  new_object_id: &str,
  w_txn: &'a W,
) -> Result<(), anyhow::Error>
where
  W: YrsDocAction<'a>,
  PersistenceError: From<W::Error>,
{
  let collab = Collab::new_with_doc_state(CollabOrigin::Empty, new_object_id, doc_state, vec![])?;
  import_collab_object(&collab, new_uid, new_object_id, w_txn);
  Ok(())
}

fn import_workspace_views<'a, 'b, W>(
  parent_view_id: &str,
  old_to_new_id_map: &mut OldToNewIdMap,
  other_session: &Session,
  other_collab_read_txn: &W,
) -> Result<Vec<ParentChildViews>, PersistenceError>
where
  'a: 'b,
  W: YrsDocAction<'a>,
  PersistenceError: From<W::Error>,
{
  let other_folder_collab = Collab::new(
    other_session.user_id,
    &other_session.user_workspace.id,
    "phantom",
    vec![],
  );
  other_folder_collab.with_origin_transact_mut(|txn| {
    other_collab_read_txn.load_doc_with_txn(
      other_session.user_id,
      &other_session.user_workspace.id,
      txn,
    )
  })?;
  let other_user_id = UserId::from(other_session.user_id);
  let other_folder = Folder::open(
    other_user_id,
    Arc::new(MutexCollab::from_collab(other_folder_collab)),
    None,
  )
  .map_err(|err| PersistenceError::InvalidData(err.to_string()))?;
  let other_folder_data = other_folder
    .get_folder_data()
    .ok_or(PersistenceError::Internal(anyhow!(
      "Can't read the folder data"
    )))?;

  // replace the old parent view id of the workspace
  old_to_new_id_map.0.insert(
    other_session.user_workspace.id.clone(),
    parent_view_id.to_string(),
  );
  let trash_ids = other_folder_data
    .trash
    .into_values()
    .flatten()
    .map(|item| old_to_new_id_map.renew_id(&item.id))
    .collect::<Vec<String>>();

  // 1. Replace the workspace views id to new id
  let mut first_level_views = other_folder_data
    .workspace
    .child_views
    .items
    .into_iter()
    .filter(|view| !trash_ids.contains(&view.id))
    .collect::<Vec<ViewIdentifier>>();

  first_level_views.iter_mut().for_each(|view_identifier| {
    view_identifier.id = old_to_new_id_map.renew_id(&view_identifier.id);
  });

  let mut all_views = other_folder_data.views;
  all_views.iter_mut().for_each(|view| {
    // 2. replace the old parent view id of the view
    view.parent_view_id = old_to_new_id_map.renew_id(&view.parent_view_id);

    // 3. replace the old id of the view
    view.id = old_to_new_id_map.renew_id(&view.id);

    // 4. replace the old id of the children views
    view.children.iter_mut().for_each(|view_identifier| {
      view_identifier.id = old_to_new_id_map.renew_id(&view_identifier.id);
    });
  });

  let mut all_views_map = all_views
    .into_iter()
    .filter(|view| !trash_ids.contains(&view.id))
    .map(|view| (view.id.clone(), view))
    .collect::<HashMap<String, View>>();

  let parent_views = first_level_views
    .into_iter()
    .flat_map(
      |view_identifier| match all_views_map.remove(&view_identifier.id) {
        None => None,
        Some(view) => parent_view_from_view(view, &mut all_views_map),
      },
    )
    .collect::<Vec<ParentChildViews>>();

  Ok(parent_views)
}

fn parent_view_from_view(
  parent_view: View,
  all_views_map: &mut HashMap<String, View>,
) -> Option<ParentChildViews> {
  let child_views = parent_view
    .children
    .iter()
    .flat_map(
      |view_identifier| match all_views_map.remove(&view_identifier.id) {
        None => None,
        Some(child_view) => parent_view_from_view(child_view, all_views_map),
      },
    )
    .collect::<Vec<ParentChildViews>>();

  Some(ParentChildViews {
    parent_view,
    child_views,
  })
}

#[derive(Default)]
struct OldToNewIdMap(HashMap<String, String>);

impl OldToNewIdMap {
  fn new() -> Self {
    Self::default()
  }
  fn renew_id(&mut self, old_id: &str) -> String {
    let view_id = self
      .0
      .entry(old_id.to_string())
      .or_insert(gen_view_id().to_string());
    (*view_id).clone()
  }
}

impl Deref for OldToNewIdMap {
  type Target = HashMap<String, String>;

  fn deref(&self) -> &Self::Target {
    &self.0
  }
}

impl DerefMut for OldToNewIdMap {
  fn deref_mut(&mut self) -> &mut Self::Target {
    &mut self.0
  }
}

#[instrument(level = "debug", skip_all)]
pub async fn upload_imported_data(
  uid: i64,
  user_collab_db: Arc<RocksCollabDB>,
  workspace_id: &str,
  user_authenticator: &Authenticator,
  import_data: &ImportData,
  user_cloud_service: Arc<dyn UserCloudService>,
) -> Result<(), FlowyError> {
  // Only support uploading the collab data when the current server is AppFlowy Cloud server
  if !user_authenticator.is_appflowy_cloud() {
    return Ok(());
  }

  let (row_object_ids, document_object_ids, database_object_ids) = match import_data {
    ImportData::AppFlowyDataFolder {
      views: _,
      database_view_ids_by_database_id: _,
      row_object_ids,
      document_object_ids,
      database_object_ids,
    } => (
      row_object_ids.clone(),
      document_object_ids.clone(),
      database_object_ids.clone(),
    ),
  };

  let object_by_collab_type = tokio::task::spawn_blocking(move || {
    let collab_read = user_collab_db.read_txn();
    let mut object_by_collab_type = HashMap::new();

    event!(tracing::Level::DEBUG, "upload database collab data");
    object_by_collab_type.insert(
      CollabType::Database,
      load_and_process_collab_data(uid, &collab_read, &database_object_ids),
    );

    event!(tracing::Level::DEBUG, "upload document collab data");
    object_by_collab_type.insert(
      CollabType::Document,
      load_and_process_collab_data(uid, &collab_read, &document_object_ids),
    );

    event!(tracing::Level::DEBUG, "upload database row collab data");
    object_by_collab_type.insert(
      CollabType::DatabaseRow,
      load_and_process_collab_data(uid, &collab_read, &row_object_ids),
    );

    object_by_collab_type
  })
  .await
  .map_err(internal_error)?;

  // Upload
  let mut size_counter = 0;
  let mut objects: Vec<UserCollabParams> = vec![];
  let upload_size_limit = 2 * 1024 * 1024;
  for (collab_type, encoded_collab_by_oid) in object_by_collab_type {
    info!(
      "Batch import collab:{} ids: {:?}",
      collab_type,
      encoded_collab_by_oid.keys(),
    );
    for (oid, encoded_collab) in encoded_collab_by_oid {
      let obj_size = encoded_collab.len();
      if size_counter + obj_size > upload_size_limit && !objects.is_empty() {
        // When the limit is exceeded, batch create with the current list of objects
        // and reset for the next batch.
        info!(
          "Exceeded maximum payload size. Batch creating collab objects: {}, payload size: {}",
          objects
            .iter()
            .map(|o| o.object_id.clone())
            .collect::<Vec<_>>()
            .join(", "),
          size_counter
        );
        user_cloud_service
          .batch_create_collab_object(workspace_id, objects)
          .await?;
        objects = Vec::new();
        size_counter = 0;
      }

      // Add the current object to the batch.
      objects.push(UserCollabParams {
        object_id: oid,
        encoded_collab,
        collab_type: collab_type.clone(),
      });
      size_counter += obj_size;
    }
  }

  // After the loop, upload any remaining objects.
  if !objects.is_empty() {
    info!(
      "Batch create collab objects: {}, payload size: {}",
      objects
        .iter()
        .map(|o| o.object_id.clone())
        .collect::<Vec<_>>()
        .join(", "),
      size_counter
    );
    user_cloud_service
      .batch_create_collab_object(workspace_id, objects)
      .await?;
  }
  Ok(())
}

#[instrument(level = "debug", skip_all)]
fn load_and_process_collab_data<'a, R>(
  uid: i64,
  collab_read: &R,
  object_ids: &[String],
) -> HashMap<String, Vec<u8>>
where
  R: YrsDocAction<'a>,
  PersistenceError: From<R::Error>,
{
  load_collab_by_oid(uid, collab_read, object_ids)
    .into_iter()
    .filter_map(|(oid, collab)| {
      collab
        .encode_collab_v1()
        .encode_to_bytes()
        .ok()
        .map(|encoded_collab| (oid, encoded_collab))
    })
    .collect()
}
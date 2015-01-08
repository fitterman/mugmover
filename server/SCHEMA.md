* Schema

Hosting Service Account
  - id
  - name (type ?)
  - hosting_service_account_handle
  - access_token

Service Collection (folder, album, gallery, etc)
  - service_collection_id
  - service_account_id
  - hosting_service_folder_id
  - collection name

Photo
  - id
  - service_collection_id
  - database_uuid
  - master_uuid
  - version_uuid
  - processed_width
  - processed_height
  - name
  - filename

Face
  - id
  - photo_id
  - face_uuid
  - x, y, w, h
  - person_id
  - database_uuid
  - face_uuid

Person
  - person_id
  - primary_display_name_id

Display Names
  - id
  - person_id

json.x face.x # left
json.y face.y # top
json.w face.width
json.h face.height
json.namedFaceId face.named_face_id
json.deleted face.deleted_at.present?
json.destroyed face.destroyed? # Useful after delete operation
json.manual face.manual?
json.id face.id 
json.thumbnail face.thumbnail.blank? ? "" : "data:image/jpeg;base64,#{face.thumbnail}"

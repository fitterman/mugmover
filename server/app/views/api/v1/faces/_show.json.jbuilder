json.x face.x # left
json.y face.y # top
json.w face.width
json.h face.height
json.named_face_id face.named_face_id
json.deleted face.deleted_at.present?
json.destroyed face.destroyed? # Useful after delete operation
json.manual face.manual?
json.text face.named_face.present? ? face.named_face.public_name : nil
json.id face.id 


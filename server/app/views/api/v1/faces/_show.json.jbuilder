json.x face.x # left
json.y face.y # top
json.w face.width
json.h face.height
json.known face.named_face.present?
json.deleted face.deleted_at.present?
json.manual face.manual?
json.text face.named_face.present? ? face.named_face.public_name : nil
json.faceId face.id 


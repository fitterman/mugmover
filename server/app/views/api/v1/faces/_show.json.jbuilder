json.x face.left_scaled(@photo.scale_factor)
json.y face.top_scaled(@photo.scale_factor)
json.w face.width_scaled(@photo.scale_factor)
json.h face.height_scaled(@photo.scale_factor)
json.known face.named_face.present?
json.deleted face.deleted_at.present?
json.manual face.manual?
json.text face.named_face.present? ? face.named_face.public_name : nil
json.faceId face.id 


json.set! face.id do 
  json.extract! face, :id
  if face.thumbnail
    json.photoId face.photo_id
    json.photoUpdatedAt face.photo.updated_at.to_s(:db)
    json.thumbnail 'data:image/jpeg;base64,' + face.thumbnail
  end
end

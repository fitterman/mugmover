json.set! name.id do 
  json.extract! name, :id
  json.publicName name.public_name
  json.privateName name.private_name
  json.note name.note
  if name.face_icon.present? && !name.face_icon.thumbnail.blank?
    json.thumbnail 'data:image/jpeg;base64,' + name.face_icon.thumbnail
  else
    json.thumbnail 'https://upload.wikimedia.org/wikipedia/en/6/6f/Smiley_Face.png'
  end
  json.updatedAt name.updated_at.to_formatted_s(:db)
end

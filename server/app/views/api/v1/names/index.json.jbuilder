@named_faces.each do |name|
  json.set! name.id do 
    json.extract! name, :id
    json.extract! name, :id
    json.publicName name.public_name
    json.privateName name.private_name
    json.note (name.id % 3 == 0 ? 'Son of ...' : nil)
    json.updatedAt name.updated_at.to_formatted_s(:db)
  end
end

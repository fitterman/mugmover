json.array!(@named_faces) do |name|
  json.extract! name, :id
  json.public_name name.public_name
  json.private_name name.private_name
  json.note (name.id % 3 == 0 ? 'Son of ...' : nil)
end

json.array!(@named_faces) do |name|
  json.extract! name, :id
  json.publicName name.public_name
  json.privateName name.private_name
  json.note (name.id % 3 == 0 ? 'Son of ...' : nil)
end

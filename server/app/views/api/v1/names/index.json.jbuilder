@named_faces.each do |name|
  json.partial! 'show', name: name
end

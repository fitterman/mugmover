json.face do
  json.partial! 'api/v1/faces/show', face: @face
end
json.names do
  (@named_faces || []).each do |name|
    json.partial! 'api/v1/names/show', name: name
  end
end

json.face do
  json.partial! 'api/v1/faces/show', face: @face
end
json.names do
  json.partial! partial: 'api/v1/names/show', collection: @named_faces, as: :name
end

json.notes @photo.faces.with_deleted.map do |note|
    json.partial! 'api/v1/faces/show', face: note
end

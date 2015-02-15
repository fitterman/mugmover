json.extract! @photo, :id
json.url @photo.big_url
json.flag @photo.flag?
json.scaled_w @photo.scaled_w
json.scaled_h @photo.scaled_h
json.faces @photo.faces.with_deleted.map do |face|
    json.partial! 'api/v1/faces/show', face: face
end

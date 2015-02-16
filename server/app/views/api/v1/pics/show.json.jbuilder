json.extract! @photo, :id
json.url @photo.big_url
json.flag @photo.flag?
json.width @photo.width
json.height @photo.height
json.faces @photo.faces.with_deleted.map do |face|
    json.partial! 'api/v1/faces/show', face: face
end

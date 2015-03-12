json.extract! @photo, :id
json.thumb @photo.thumbnail_data_or_url
json.url @photo.thumbnail_data_or_url
json.flag @photo.flag?
json.width @photo.width
json.height @photo.height
json.faces @photo.faces.with_deleted.map do |face|
    json.partial! 'api/v1/faces/show', face: face
end

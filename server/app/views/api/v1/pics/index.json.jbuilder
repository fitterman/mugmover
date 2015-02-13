json.totalPhotos @total_photos
json.photosPerRequest Api::V1::PicsController::PAGESIZE
json.photos do
  json.array!(@photos) do |photo|
    json.extract! photo, :id
    json.url api_v1_pic_url(a_id: params[:a_id], id: photo.id, format: :json)
    json.thumb photo.thumbnail_url
    json.scaled_w "#{Integer(photo.width * photo.scale_factor)}px"
    json.scaled_h "#{Integer(photo.height * photo.scale_factor)}px"
    json.index @index
    @index += 1
  end
end

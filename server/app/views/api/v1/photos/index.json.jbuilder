json.totalPhotos @total_photos
json.photosPerRequest @photos_per_request
json.page @page
json.photos do
  json.array!(@photos) do |photo|
    json.extract! photo, :id
    json.url api_v1_photo_url(a_id: params[:a_id], id: photo.id, format: :json)
    json.thumb photo.thumbnail_data_or_url
    json.width photo.width
    json.height photo.height
    json.index @index
    @index += 1
  end
end

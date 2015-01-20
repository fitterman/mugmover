json.array!(@photos) do |photo|
  json.extract! photo, :id
  json.url api_v1_pic_url(a_id: params[:a_id], id: photo.id, format: :json)
  json.thumb photo.thumbnail_url
  json.index @index
  @index += 1
end

index = (@photos.page.to_i - 1) * @photos.perpage.to_i
json.array!(@photos) do |photo|
  json.extract! photo, :id
  json.url flickr_photo_url(params[:flickr_id], photo.id, format: :json)
  json.thumb FlickRaw.url_t(photo)
  json.index index
  index += 1
end

require 'flickraw'

class Flickr

  FlickRaw.api_key = ENV['MUGMOVER_API_KEY']
  FlickRaw.shared_secret = ENV['MUGMOVER_SHARED_SECRET']

  def self.get_photos(user_id)
    # We are temporarily using getPublicPhotos just to get this running
    # but we ought to use flickr.photos.getPhotos
    return flickr.people.getPublicPhotos(user_id: user_id)
  end

  def self.get_info(owner_id, photo_id)
    info = flickr.photos.getInfo(photo_id: photo_id)
    return info
  end

end
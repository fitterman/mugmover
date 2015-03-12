class Photo < ActiveRecord::Base

  belongs_to  :hosting_service_account
  has_many    :faces

  #validates   :database_uuid,       presence: true
  validates   :master_uuid,         presence: true
  validates   :version_uuid,        presence: true
  validates   :width,     inclusion: 50..20000
  validates   :height,    inclusion: 50..20000
  validates     :name,               presence: {allow_nil: true}
  #validates   :filename,            presence: true
  #validates   :format,              inclusion: %w{jpeg png gif tiff raw}

  serialize     :request, JSON

#   before_save   :populate_urls
  before_save   :normalize_flag

  def self.from_hash(hosting_service_account, database_uuid, photo_hash, full_hash)
    # service_photo_id = service_hash['id'] || "TODO hosting_service_photo_id"
    photo = Photo.find_or_create_by(hosting_service_account_id: hosting_service_account.id,
                                    database_uuid: database_uuid,
                                    master_uuid: photo_hash['masterUuid']
                             #       hosting_service_photo_id: service_photo_id
                                    ) do |new_user|
    end
    photo.width = photo_hash['processedWidth']
    photo.height = photo_hash['processedHeight']
    photo.version_uuid = photo_hash['versionUuid']
    photo.master_uuid = photo_hash['masterUuid']
    photo.database_uuid = database_uuid
    photo.original_date = photo_hash['originalDate']
#    photo.date_uploaded = service_hash['dateUploaded']
#    photo.original_format = service_hash['originalFormat']
    photo.thumbnail = photo_hash['thumbnail']
    photo.request = full_hash
    require 'pp' ; pp photo
    photo.save
    return photo
  end

  def thumbnail_data_or_url
    thumbnail.blank? ? thumbnail_url : ('data:image/jpeg;base64,' + self.thumbnail)
  end

  # Ensure it has a valid value
  def normalize_flag
    if self.flag.nil?
      self.flag = 0
    end
  end

  def populate_urls
    hash = request['service']
    if hash['name'] == 'flickr'
      farm = hash['farm']
      server = hash['server']
      phid = hash['id']
      secret = hash['secret']
      self.thumbnail_url = "https://farm#{farm}.staticflickr.com/#{server}/#{phid}_#{secret}_t.jpg"
      self.big_url = "https://farm#{farm}.staticflickr.com/#{server}/#{phid}_#{secret}_b.jpg"
    else
      raise StandardError.new("Unexpected service (name=#{hash['name']}")
    end
  end

end

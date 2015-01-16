class Photo < ActiveRecord::Base

  #validates   :database_uuid,       presence: true
  validates   :master_uuid,         presence: true
  validates   :version_uuid,        presence: true
  validates   :width,     inclusion: 50..20000
  validates   :height,    inclusion: 50..20000
  validates   :name,                presence: {allow_nil: true}
  #validates   :filename,            presence: true
  #validates   :format,              inclusion: %w{jpeg png gif tiff raw}

  serialize :request, JSON

  def self.from_request(hosting_service_account, database_uuid, service_hash, photo_hash)
    service_photo_id = service_hash['id']
    photo = Photo.find_or_create_by(hosting_service_account_id: hosting_service_account.id,
                                    hosting_service_photo_id: service_photo_id) do |new_user|
    end
    photo.width = service_hash.delete('width') || photo_hash['width']
    photo.height = service_hash.delete('height') || photo_hash['height']
    photo.version_uuid = photo_hash['versionUuid']
    photo.master_uuid = photo_hash['masterUuid']
    photo.database_uuid = database_uuid
    photo.original_date = photo_hash['originalDate']
    photo.date_uploaded = service_hash['dateUploaded']
    photo.original_format = service_hash['originalFormat']
    photo.request = photo_hash
    return photo
  end

end

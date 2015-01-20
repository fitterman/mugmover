class HostingServiceAccount < ActiveRecord::Base

  has_many    :photos
  has_many    :named_faces

  validates   :name,          inclusion: %w{flickr}, 
                              presence: {allow_blank: false}
  validates   :handle,        presence: {allow_blank: false}
#  validates   :handle,       inclusion: %w{127850168@N06}
#  validates   :auth_token,   presence: true

  def self.from_hash(service_hash)
    service_name = service_hash.delete('name')
    service_handle = service_hash['owner']

    hosting_service_account = HostingServiceAccount.find_or_create_by(name: service_name, 
                                                                      handle: service_handle)
    hosting_service_account.save
    hosting_service_account
  end

end
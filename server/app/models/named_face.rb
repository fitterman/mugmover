class NamedFace < ActiveRecord::Base

  belongs_to  :hosting_service_account
  has_many    :faces

  default_scope { order('public_name') } 

  validates   :face_key,               presence: {allow_blank: false}
  validates   :face_name_uuid,         presence: {allow_blank: false}
  validates   :private_name,           presence: {allow_blank: false}
  validates   :public_name,            presence: {allow_blank: false}

  def png_thumbnail
    Base64.encode64(open('/Users/bob/Downloads/logo-200x200.png') { |io| io.read })
  end
end
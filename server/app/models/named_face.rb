class NamedFace < ActiveRecord::Base

  belongs_to  :hosting_service_account
  has_many    :faces

  validates   :face_key,               presence: {allow_blank: false}
  validates   :face_name_uuid,         presence: {allow_blank: false}
  validates   :private_name,           presence: {allow_blank: false}
  validates   :public_name,            presence: {allow_blank: false}

end
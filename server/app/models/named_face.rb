class NamedFace < ActiveRecord::Base

  belongs_to  :hosting_service_account

  validates   :face_key,               presence: {allow_blank: false}
  validates   :face_name_uuid,         presence: {allow_blank: false}

end
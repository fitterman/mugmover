class NamedFace < ActiveRecord::Base

  validates   :face_key,               presence: {allow_blank: false}
  validates   :face_name_uuid,         presence: {allow_blank: false}

end
class NamedFace < ActiveRecord::Base

  validates   :face_name_uuid,         presence: {allow_blank: false}

end
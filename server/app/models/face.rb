class Face < ActiveRecord::Base

  validates   :photo_id,            presence: true
  validates   :face_uuid,           presence: true
  validates   :center_x,            numericality: { only_integer: true } # could be negative after cropping
  validates   :center_y,            numericality: { only_integer: true } # could be negative after cropping
  validates   :width,               numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates   :height,              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates   :named_face_id,       presence: true

  ## TODO Add rejected and figure out how manually-added faces are treated (vs automatic and rejected).
  ## Also add the facekey which associates a face to a name. Add the facekey in the person table
  ## (then add the name in the display_names table)
end

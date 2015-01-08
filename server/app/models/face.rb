class Face < ActiveRecord::Base

  validates   :photo_id,            presence: true
  validates   :database_uuid,       presence: true
  validates   :face_uuid,           presence: true
  validates   :x,                   numericality: {greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0}
  validates   :y,                   numericality: {greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0}
  validates   :w,                   numericality: {greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0}
  validates   :h,                   numericality: {greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0}
  validates   :person_id,           presence: true

  ## TODO Add rejected and figure out how manually-added faces are treated (vs automatic and rejected).
  ## Also add the facekey which associates a face to a name. Add the facekey in the person table
  ## (then add the name in the display_names table)
end

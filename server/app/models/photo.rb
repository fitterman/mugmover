class Photo < ActiveRecord::Base

  validates   :database_uuid,       presence: true
  validates   :master_uuid,         presence: true
  validates   :version_uuid,        presence: true
  validates   :processed_width,     inclusion: 50..10000
  validates   :processed_height,    inclusion: 50..10000
  validates   :name,                presence: true
  validates   :filename,            presence: true
  validates   :format,              inclusion: %w{jpeg png gif tiff raw}

end

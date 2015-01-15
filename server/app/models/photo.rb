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

end

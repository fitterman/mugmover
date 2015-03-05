class AddThumbnailToFaceName < ActiveRecord::Migration
  def change
    add_column :named_faces, :face_icon_id, :integer
    add_column :faces, :thumbscale, :float
  end
end

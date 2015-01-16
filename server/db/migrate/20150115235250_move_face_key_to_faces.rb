class MoveFaceKeyToFaces < ActiveRecord::Migration
  def change
    add_column :faces, :face_key, :integer
    remove_column :faces, :face_name_uuid, :string
  end
end

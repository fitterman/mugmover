class AddPublicNameToNamedFaces < ActiveRecord::Migration
  def change
    add_column :named_faces, :public_name, :string
    add_column :named_faces, :private_name, :string
    remove_column :named_faces, :primary_display_name_id, :string
    drop_table :display_names
  end
end

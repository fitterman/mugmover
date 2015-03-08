class AddAndRenameManyColumns < ActiveRecord::Migration
  def change
    add_column :photos, :hosting_service_account_id, :integer
    add_column :photos, :hosting_service_photo_id, :string
    add_column :photos, :original_date, :string
    add_column :photos, :request, :text
    rename_column :photos, :processed_width, :width
    rename_column :photos, :processed_height, :height

    rename_column :display_names, :person_id, :named_face_id

    create_table :named_faces do |t|
      t.integer :hosting_service_account_id
      t.string :database_uuid
      t.string :face_name_uuid
      t.integer :face_key
      t.integer :primary_display_name_id
    end

    rename_column :faces, :person_id, :named_face_id
    rename_column :faces, :x, :center_x
    rename_column :faces, :y, :center_y
    rename_column :faces, :w, :width
    rename_column :faces, :h, :height

    add_column :faces, :ignore, :boolean
    add_column :faces, :rejected, :boolean
    add_column :faces, :visible, :boolean

    remove_column :faces, :database_uuid
    drop_table :people
  end
end

class CreateFaces < ActiveRecord::Migration
  def change
    create_table :faces do |t|
      t.integer :photo_id
      t.string :database_uuid
      t.string :face_uuid
      t.float :x
      t.float :y
      t.float :w
      t.float :h
      t.integer :person_id
      t.string :timestamps
    end
  end
end

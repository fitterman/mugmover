class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.integer :service_collection_id
      t.string :database_uuid
      t.string :master_uuid
      t.integer :version_uuid
      t.integer :processed_width
      t.integer :processed_height
      t.string :name
      t.string :filename
      t.timestamps
    end
  end
end

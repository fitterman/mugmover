class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.string :provider
      t.string :account
      t.string :unique_id
      t.timestamps
    end
  end
end

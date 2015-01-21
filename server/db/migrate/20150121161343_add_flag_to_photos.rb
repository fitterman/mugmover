class AddFlagToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :flag, :integer
  end
end

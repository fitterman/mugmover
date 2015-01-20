class AddUrlsToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :thumbnail_url, :string
    add_column :photos, :big_url, :string
  end
end

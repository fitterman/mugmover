class AddFieldsToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :web_url, :string
    add_column :photos, :original_url, :string
    add_column :photos, :large_url, :string
  end
end

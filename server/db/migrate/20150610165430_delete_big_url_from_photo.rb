class DeleteBigUrlFromPhoto < ActiveRecord::Migration
  def change
    remove_column :photos, :big_url, :string
    remove_column :photos, :thumbnail_url, :string
  end
end

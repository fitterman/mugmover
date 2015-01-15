class AddDateUploadedToPhoto < ActiveRecord::Migration
  def change
    add_column :photos, :date_uploaded, :timestamp
    add_column :photos, :original_format, :string
  end
end

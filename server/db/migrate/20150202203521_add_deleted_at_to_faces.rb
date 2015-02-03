class AddDeletedAtToFaces < ActiveRecord::Migration
  def change
    add_column :faces, :deleted_at, :datetime
    add_index :faces, :deleted_at
    remove_column :faces, :rejected, :boolean
    remove_column :faces, :ignore, :boolean
  end
end

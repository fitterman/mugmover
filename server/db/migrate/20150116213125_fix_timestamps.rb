class FixTimestamps < ActiveRecord::Migration
  def change
    add_column :display_names, :created_at, :datetime
    add_column :display_names, :updated_at, :datetime
    remove_column :display_names, :timestamp, :string
    remove_column :display_names, :timestamps, :string

    add_column :faces, :created_at, :datetime
    add_column :faces, :updated_at, :datetime
    remove_column :faces, :timestamp, :string
    remove_column :faces, :timestamps, :string

    add_column :named_faces, :created_at, :datetime
    add_column :named_faces, :updated_at, :datetime

  end
end

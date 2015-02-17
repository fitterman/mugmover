class RenameXY < ActiveRecord::Migration
  def change
    rename_column :faces, :center_x, :x
    rename_column :faces, :center_y, :y
  end
end

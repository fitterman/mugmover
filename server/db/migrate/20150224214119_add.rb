class Add < ActiveRecord::Migration
  def change
    add_column :faces, :thumbnail, :text
  end
end

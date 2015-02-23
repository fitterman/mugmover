class AddNotesToNamedFaces < ActiveRecord::Migration
  def change
    add_column :named_faces, :note, :text
  end
end

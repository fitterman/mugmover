class AddManualToFace < ActiveRecord::Migration
  def change
    add_column :faces, :manual, :integer
  end
end

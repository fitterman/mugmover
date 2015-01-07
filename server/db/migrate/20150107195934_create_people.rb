class CreatePeople < ActiveRecord::Migration
  def change
    create_table :people do |t|
      t.integer :primary_display_name_id
      t.string :timestamps
    end
  end
end

class CreateDisplayNames < ActiveRecord::Migration
  def change
    create_table :display_names do |t|
      t.integer :person_id
      t.string :name
      t.string :timestamps
    end
  end
end

class CreateServiceCollection < ActiveRecord::Migration
  def change
    create_table :service_collections do |t|
      t.string :name
      t.integer :hosting_service_account_id
      t.string :hosting_service_folder_id
      t.timestamps
    end
  end
end

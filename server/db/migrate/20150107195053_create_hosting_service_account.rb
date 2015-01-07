class CreateHostingServiceAccount < ActiveRecord::Migration
  def change
    create_table :hosting_service_accounts do |t|
      t.string :name
      t.string :hosting_service_account_handle
      t.string :access_token
      t.timestamps
    end
  end
end

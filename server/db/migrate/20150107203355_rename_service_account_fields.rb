class RenameServiceAccountFields < ActiveRecord::Migration
  def change
    rename_column :hosting_service_accounts, :access_token, :auth_token
    rename_column :hosting_service_accounts, :hosting_service_account_handle, :handle
  end
end

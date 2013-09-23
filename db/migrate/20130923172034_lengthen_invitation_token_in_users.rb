class LengthenInvitationTokenInUsers < ActiveRecord::Migration
  def change
	change_column :users, :invitation_token, :string, :limit => 66
  end
end

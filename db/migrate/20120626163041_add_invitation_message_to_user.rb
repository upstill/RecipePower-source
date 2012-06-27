class AddInvitationMessageToUser < ActiveRecord::Migration
  def change
    add_column :users, :invitation_message, :text
  end
end

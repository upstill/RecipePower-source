class AddInvitationIssuerToUsers < ActiveRecord::Migration
  def change
    add_column :users, :invitation_issuer, :string
  end
end

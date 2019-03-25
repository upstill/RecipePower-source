class AddValidityToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :email_valid, :boolean
  end
end

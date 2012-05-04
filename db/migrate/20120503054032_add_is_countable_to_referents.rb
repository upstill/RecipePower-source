class AddIsCountableToReferents < ActiveRecord::Migration
  def change
    add_column :referents, :isCountable, :boolean
  end
end

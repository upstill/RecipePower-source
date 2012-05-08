class AddDescriptionToReferents < ActiveRecord::Migration
  def change
    add_column :referents, :description, :string
  end
end

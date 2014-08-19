class AddEntityTypeToRcpref < ActiveRecord::Migration
  def change
    add_column :rcprefs, :entity_type, :string, default: "Recipe"
    rename_column :rcprefs, :recipe_id, :entity_id
  end
end

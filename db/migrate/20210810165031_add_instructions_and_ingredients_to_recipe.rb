class AddInstructionsAndIngredientsToRecipe < ActiveRecord::Migration[5.2]
  def up
    remove_column :recipes, :prep_time
    remove_column :recipes, :cook_time
    remove_column :recipes, :total_time
    add_column :recipes, :prep_time, :int4range
    add_column :recipes, :cook_time, :int4range
    add_column :recipes, :total_time, :int4range
    add_column :recipes, :instructions, :string
    add_column :recipes, :ingredients, :string
    add_column :recipes, :serves, :int4range
    remove_column :recipes, :prep_time_low
    remove_column :recipes, :prep_time_high
    remove_column :recipes, :cook_time_low
    remove_column :recipes, :cook_time_high
    remove_column :recipes, :total_time_low
    remove_column :recipes, :total_time_high
    rename_column :recipes, :yield, :yields
  end
  def down
    remove_column :recipes, :prep_time
    remove_column :recipes, :cook_time
    remove_column :recipes, :total_time
    add_column :recipes, :prep_time, :string
    add_column :recipes, :cook_time, :string
    add_column :recipes, :total_time, :string
    remove_column :recipes, :instructions
    remove_column :recipes, :ingredients
    remove_column :recipes, :serves
    add_column :recipes, :prep_time_low, :integer, default: 0
    add_column :recipes, :prep_time_high, :integer, default: 0
    add_column :recipes, :cook_time_low, :integer, default: 0
    add_column :recipes, :cook_time_high, :integer, default: 0
    add_column :recipes, :total_time_low, :integer, default: 0
    add_column :recipes, :total_time_high, :integer, default: 0
    rename_column :recipes, :yields, :yield
  end
end

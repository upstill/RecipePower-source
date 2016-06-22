class AddTimesToRecipes < ActiveRecord::Migration
  def change
    add_column :recipes, :prep_time, :string
    add_column :recipes, :cook_time, :string
    add_column :recipes, :total_time, :string
    add_column :recipes, :prep_time_low, :integer, default: 0
    add_column :recipes, :prep_time_high, :integer, default: 0
    add_column :recipes, :cook_time_low, :integer, default: 0
    add_column :recipes, :cook_time_high, :integer, default: 0
    add_column :recipes, :total_time_low, :integer, default: 0
    add_column :recipes, :total_time_high, :integer, default: 0
    add_column :recipes, :yield, :string
  end
end

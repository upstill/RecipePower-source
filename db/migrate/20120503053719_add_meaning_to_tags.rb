class AddMeaningToTags < ActiveRecord::Migration
  def change
    add_column :tags, :meaning, :integer
  end
end

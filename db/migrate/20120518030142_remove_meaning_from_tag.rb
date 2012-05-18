class RemoveMeaningFromTag < ActiveRecord::Migration
  def up
    remove_column :tags, :meaning
    add_column :tags, :referent_id, :integer
  end

  def down
    remove_column :tags, :referent_id
    add_column :tags, :meaning, :integer
  end
end

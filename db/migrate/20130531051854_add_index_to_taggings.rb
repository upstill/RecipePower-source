class AddIndexToTaggings < ActiveRecord::Migration
  def up
   add_index  :taggings, [:user_id, :tag_id, :entity_id, :entity_type, :is_definition], :unique => true, :name => :tagging_unique
  end

  def down
   remove_index  :taggings, :name => :tagging_unique
  end
end

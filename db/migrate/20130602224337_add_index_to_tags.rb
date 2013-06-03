class AddIndexToTags < ActiveRecord::Migration
  def up
   add_index  :tags, [:name, :tagtype], :unique => true, :name => :tag_name_type_unique
   add_index  :tags, [:normalized_name], :name => :tag_normalized_name_index
  end

  def down
   remove_index  :tags, :name => :tag_name_type_unique
   remove_index  :tags, :normalized_name => :tag_normalized_name_index
  end
end

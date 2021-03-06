class AddIndexToExpressions < ActiveRecord::Migration[4.2]
  def up
   add_index  :expressions, [:referent_id, :tag_id, :form, :locale], :unique => true, :name => :expression_unique
  end

  def down
   remove_index  :expressions, :name => :expression_unique
  end
end

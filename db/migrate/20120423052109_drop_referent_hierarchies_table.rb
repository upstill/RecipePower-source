class DropReferentHierarchiesTable < ActiveRecord::Migration
  def up
  	drop_table :referent_hierarchies
  end

  def down
  create_table "referent_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id",   :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations",   :null => false
  end
  end
end

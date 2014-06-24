class DropLinkRefs < ActiveRecord::Migration
  def up
    drop_table :link_refs
  end

  def down
    create_table :link_refs do |t|
      t.integer  :link_id
      t.integer  :tag_id
      t.integer  :owner_id
      t.timestamps
    end
  end
end

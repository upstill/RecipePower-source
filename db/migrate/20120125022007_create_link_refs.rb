class CreateLinkRefs < ActiveRecord::Migration
  def self.up
    create_table :link_refs do |t|
      t.integer :link_id
      t.integer :tag_id
      t.integer :owner_id

      t.timestamps
    end

  end

  def self.down
    drop_table :link_refs
  end

end

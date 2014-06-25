class DropSiteReferents < ActiveRecord::Migration
  def self.up
    drop_table :site_referents
  end

  def self.down
    create_table :site_referents do |t|
      t.string   "site"
      t.string   "sample"
      t.string   "home"
      t.string   "subsite"
      t.string   "scheme"
      t.string   "host"
      t.string   "port"
      t.string   "logo"
      t.text     "tags_serialized"
      t.string   "ttlcut"
      t.string   "ttlrepl"
      t.timestamps
    end
  end
end

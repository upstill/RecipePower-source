class AddDjIds < ActiveRecord::Migration
  def change
    add_column :feeds, :dj_id, :integer
    add_column :gleanings, :dj_id, :integer
    add_column :references, :dj_id, :integer
    add_column :scrapers, :dj_id, :integer
  end
end

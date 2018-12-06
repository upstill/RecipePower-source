class AddDjIds < ActiveRecord::Migration[4.2]
  def change
    add_column :feeds, :dj_id, :integer
    add_column :gleanings, :dj_id, :integer
    add_column :references, :dj_id, :integer
    add_column :scrapers, :dj_id, :integer
  end
end

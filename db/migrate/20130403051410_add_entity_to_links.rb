class AddEntityToLinks < ActiveRecord::Migration
  def change
    add_column :links, :entity_id, :integer
    add_column :links, :entity_type, :string
  end
end

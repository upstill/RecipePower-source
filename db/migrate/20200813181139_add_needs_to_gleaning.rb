class AddNeedsToGleaning < ActiveRecord::Migration[5.2]
  def change
    add_column :gleanings, :needs, :text, array: true, default: []
  end
end

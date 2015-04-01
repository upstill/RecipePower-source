class AddRatingToRcprefs < ActiveRecord::Migration
  def change
    add_column :rcprefs, :rating, :integer
  end
end

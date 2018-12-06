class ChangeStatusForSite < ActiveRecord::Migration[4.2]
  def up
	change_column :sites, :status, :integer, default: 0
	change_column :recipes, :status, :integer, default: 0
	Recipe.where(status: [0, nil]).each { |recipe| recipe.update_attribute(:status, 3) }
	Site.where(status: [0, nil]).each { |site| site.update_attribute(:status, 3) }
  end
  def down
	change_column :sites, :status, :integer
	change_column :recipes, :status, :integer
  end
end

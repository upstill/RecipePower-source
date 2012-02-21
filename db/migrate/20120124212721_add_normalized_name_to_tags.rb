class AddNormalizedNameToTags < ActiveRecord::Migration
  def change
    add_column :tags, :normalized_name, :string
    add_column :tags, :isGlobal, :boolean
    Tag.all.each { |tag| tag.save } # Fill in the normalized name
  end
end

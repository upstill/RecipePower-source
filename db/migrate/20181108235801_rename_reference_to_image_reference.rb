class Reference < ApplicationRecord
end
class RenameReferenceToImageReference < ActiveRecord::Migration
  def up
    drop_table :image_references if ActiveRecord::Base.connection.table_exists?("image_references")
    remove_index(:references, name: "references_index_by_url_and_type") if index_name_exists?(:references, "references_index_by_url_and_type", false)
    Reference.where.not(type: 'ImageReference').delete_all
    remove_column :references, :type
    rename_table :references, :image_references
    Referment.where(referee_type: 'Reference').each { |rfm| rfm.update_attribute :referee_type, 'ImageReference'}
    add_index(:image_references, :url, unique: true, using: 'btree', name: "image_references_index_by_url") unless index_name_exists?(:image_references, "image_references_index_by_url", false)
  end
  def down
    rename_table :image_references, :references
    add_column :references, :type, default: 'ImageReference'
  end
end

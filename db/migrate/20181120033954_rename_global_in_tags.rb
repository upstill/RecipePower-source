class RenameGlobalInTags < ActiveRecord::Migration[4.2]
  def change
    rename_column :tags, :isGlobal, :is_global
  end
end

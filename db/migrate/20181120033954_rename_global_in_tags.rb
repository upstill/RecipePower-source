class RenameGlobalInTags < ActiveRecord::Migration
  def change
    rename_column :tags, :isGlobal, :is_global
  end
end

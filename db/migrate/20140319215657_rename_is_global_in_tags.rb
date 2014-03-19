class RenameIsGlobalInTags < ActiveRecord::Migration
  def up
    rename_column :tags, :isGlobal, :is_global
  end
  def down
    rename_column :tags, :is_global, :isGlobal
  end
end

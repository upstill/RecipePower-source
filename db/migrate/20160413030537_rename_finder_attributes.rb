class RenameFinderAttributes < ActiveRecord::Migration[4.2]
  def change
    rename_column :finders, :finds, :label
    rename_column :finders, :read_attrib, :attribute_name
  end
end

class RenameFinderAttributes < ActiveRecord::Migration
  def change
    rename_column :finders, :finds, :label
    rename_column :finders, :read_attrib, :attribute_name
  end
end

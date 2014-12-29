class AddHostToReferences < ActiveRecord::Migration
  def up
    add_column :references, :host, :string
    Reference.all.each { |ref| ref.save }
  end
  def down
    remove_column :references, :host
  end
end

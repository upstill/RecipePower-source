class CreateListsTags < ActiveRecord::Migration
  def change
    create_table :lists_tags do |t|
      t.integer :tag_id
      t.integer :list_id
    end
  end
end

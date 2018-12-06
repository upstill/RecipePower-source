class CreateListsTags < ActiveRecord::Migration[4.2]
  def change
    create_table :lists_tags do |t|
      t.integer :tag_id
      t.integer :list_id
    end
  end
end

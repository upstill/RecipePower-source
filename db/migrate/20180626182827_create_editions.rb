class CreateEditions < ActiveRecord::Migration
  def change
    create_table :editions do |t|
      t.text :opening
      t.text :signoff
      t.integer :recipe_id
      t.text :recipe_before
      t.text :recipe_after
      t.integer :site_id
      t.text :site_before
      t.text :site_after
      t.integer :list_id
      t.text :list_before
      t.text :list_after
      t.integer :guest_id
      t.text :guest_before
      t.text :guest_after
      t.integer :list_id
      t.text :list_before
      t.text :list_after

      t.timestamps null: false
    end
  end
end

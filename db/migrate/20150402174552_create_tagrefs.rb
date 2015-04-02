class CreateTagrefs < ActiveRecord::Migration
  def change
    create_table :tagrefs do |t|
      t.boolean :primary
      t.references :tag, index: true
      t.references :tagset, index: true

      t.timestamps null: false
    end
    add_foreign_key :tagrefs, :tags
    add_foreign_key :tagrefs, :tagsets
  end
end

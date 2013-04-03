class CreateTaggings < ActiveRecord::Migration
  def change
    create_table :taggings do |t|
      t.integer :user_id
      t.integer :tag_id
      t.integer :entity_id
      t.string  :entity_type
      t.boolean :is_definition, default: false

      t.timestamps
    end
  end
end

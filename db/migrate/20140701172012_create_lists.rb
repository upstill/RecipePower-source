class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.integer :owner_id
      t.integer :name_tag_id
      t.integer :availability, default: 0
      t.text :ordering, default: ""
      t.text :description, default: ""
      t.text :notes, default: ""

      t.timestamps
    end

    create_table :lists_tags do |t|
      t.integer :tag_id
      t.integer :list_id

      t.timestamps
    end

    create_table :lists_users do |t|
      t.integer :list_id
      t.integer :user_id
    end
  end
end

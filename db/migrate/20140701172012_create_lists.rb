class CreateLists < ActiveRecord::Migration
  def up
    create_table :lists, :force => true do |t|
      t.integer :owner_id
      t.integer :name_tag_id
      t.integer :availability, default: 0
      t.text :ordering, default: ""
      t.text :description, default: ""
      t.text :notes, default: ""
      t.boolean :pullin, default: true

      t.timestamps
    end

    create_table :lists_tags, :force => true do |t|
      t.integer :tag_id
      t.integer :list_id

      t.timestamps
    end

    create_table :lists_users, :force => true do |t|
      t.integer :list_id
      t.integer :user_id
    end 
  end

  def down
    drop_table :lists
    drop_table :lists_tags
    drop_table :lists_users
  end

end

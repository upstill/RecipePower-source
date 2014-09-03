class CreateLists < ActiveRecord::Migration
  def up
    create_table :lists do |t|
      t.integer :owner_id
      t.integer :name_tag_id
      t.integer :availability, default: 0
      t.text :ordering, default: ""
      t.text :description, default: ""
      t.text :notes, default: ""

      t.timestamps
    end unless ActiveRecord::Base.connection.table_exists?("lists")

    create_table :lists_tags do |t|
      t.integer :tag_id
      t.integer :list_id

      t.timestamps
    end unless ActiveRecord::Base.connection.table_exists?("lists_tags")

    create_table :lists_users do |t|
      t.integer :list_id
      t.integer :user_id
    end unless ActiveRecord::Base.connection.table_exists?("lists_users")
  end

  def down
    drop_table :lists
    drop_table :lists_tags
    drop_table :lists_users
  end

end

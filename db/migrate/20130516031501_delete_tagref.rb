class DeleteTagref < ActiveRecord::Migration
  def up
    drop_table :tagrefs
  end

  def down
    create_table :tagrefs do |t|
      t.integer  :recipe_id
      t.integer  :tag_id
      t.integer  :user_id
      t.timestamps
    end
  end
end

class CreateTagsets < ActiveRecord::Migration
  def change
    create_table :tagsets do |t|
      t.string :title
      t.integer :tagtype

      t.timestamps null: false
    end
  end
end

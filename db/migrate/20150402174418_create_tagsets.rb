class CreateTagsets < ActiveRecord::Migration
  def change
    create_table :tagsets do |t|
      t.string :label

      t.timestamps null: false
    end
  end
end

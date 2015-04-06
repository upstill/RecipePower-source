class CreateTagsets < ActiveRecord::Migration
  def change
    create_table :tagsets do |t|
      t.string :title
      t.integer :tagtype

      t.timestamps null: false
      Tagset.create title: "Cookbook"
      Tagset.create title: "Cocktail"
      Tagset.create title: "Tool"
    end
  end
end

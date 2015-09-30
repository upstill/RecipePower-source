class CreateTagsets < ActiveRecord::Migration
  def change
    unless ActiveRecord::Base.connection.table_exists?("tagsets")
      create_table :tagsets do |t|
        t.string :title
        t.integer :tagtype

        t.timestamps null: false
      end
      Tagset.create title: "Cookbook"
      Tagset.create title: "Cocktail"
      Tagset.create title: "Quick Dinner"
      Tagset.create title: "Breakfast"
      Tagset.create title: "Lunch"
      Tagset.create title: "Weeknight Dinner"
      Tagset.create title: "Fancy Spread"
      Tagset.create title: "Kidfood"
      Tagset.create title: "Tool"
    end
  end
end

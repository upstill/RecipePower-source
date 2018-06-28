class CreateEditions < ActiveRecord::Migration
  def change
    create_table :editions do |t|
      t.text :opening
      t.text :signoff
      t.integer :recipe_id
      t.text :recipe_before
      t.text :recipe_after
      t.integer :condiment_id
      t.string :condiment_type, default: 'IngredientReferent'
      t.text :condiment_before
      t.text :condiment_after
      t.integer :site_id
      t.text :site_before
      t.text :site_after
      t.integer :list_id
      t.text :list_before
      t.text :list_after
      t.integer :guest_id
      t.string :guest_type, default: 'AuthorReferent'
      t.text :guest_before
      t.text :guest_after
      t.boolean :published, default: false
      t.date :published_at
      t.integer :number

      t.timestamps null: false
    end
    Edition.create "opening"=>"I'd like to invite you to my new project, the RecipePower Newsletter. After years of work, the site is finally ready for prime time, and I want to use it myself. RecipePower is about wrangling the best recipes and food-related information from around the Web, and this newsletter will be a weekly jolt of inspiration from my kitchen to yours.\r\n\r\nIn fact, here it is--slightly padded out by introductions to the departments. Clicking on one of the links will save the appropriate entry for you in RecipePower in addition to taking you to the thing itself.", "signoff"=>"Th...th...that's all, folks! If you have suggestions for any recipes, sites, etc. that you love, please, say something! In fact, any communication is good communication. Just shoot an email to recipepowerfeedback@gmail.com.", "recipe_id"=>15204, "recipe_before"=>"Some recipes fire on all cylinders--quick, simple, economical, classic, delicious, universal appeal--but those are few and far between. We'll have one for you every time we go out.\r\n\r\nHere's a classic from the sainted Marcella Hazan. The title says it all.", "recipe_after"=>"", "condiment_id"=>nil, "condiment_before"=>nil, "condiment_after"=>nil, "site_id"=>3630, "site_before"=>"Each week we'll ferret out some food site, novel or classic, that you might want to check out.\r\n\r\nThis week, a dark horse in the hipster-food world:", "site_after"=>"They got cheek (their April Fools gag this year got me going), and they got good stuff.", "list_id"=>818, "list_before"=>"Asparagus season is almost over, but there's still time to celebrate the King of Vegetables.", "list_after"=>"", "guest_id"=>1, "guest_type"=>"User", "guest_before"=>"A guest who needs no introduction!", "guest_after"=>"Max Garrone has been helping with RecipePower since the beginning. It'll be a long time before anyone outdoes his personal collection."
  end

end

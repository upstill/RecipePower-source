class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :answer, default: ""
      t.references :user, index: true
      t.integer :question_id

      t.timestamps null: false
    end
    add_foreign_key :answers, :users
    Tag.where(tagtype: 15).each { |tag| tag.destroy }
    ["What's the best thing you've eaten lately?", "What are you all about cooking right now?", "Who's your most beloved purveyor?", "What's the sharpest tool in your kitchen?", "Fantasy dinner guest?", "Find me shopping at:", "What's the best part about cooking a nice meal?", "What's your hottest recent culinary discovery?", "What's your favorite kind of cooking?", "Who's your current culinary crush?"].each { |name| 
	Tag.create(tagtype: 15, isGlobal: true, name: name) 
    }
  end
end

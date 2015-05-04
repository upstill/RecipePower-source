class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :answer, default: ""
      t.references :user, index: true
      t.integer :question_id

      t.timestamps null: false
    end
    add_foreign_key :answers, :users
    Tag.where(tagtype: [15,17]).each { |tag| tag.destroy }
    ["What's the best thing you've eaten lately?",
	"For my last meal, serve me:",
	"What are you all about cooking right now?",
	"Who's your most beloved purveyor?",
	"What tool will we have to pry from your cold, dead hands?",
	"Who's your #1 fantasy dinner guest?",
	"Find me shopping at:",
	"Location:",
	"Give me an unlimited budget and send me shopping at:",
	"Favorite funky place to eat?",
	"Best kitchen secret?",
	"What's the best part about cooking a nice meal?",
	"What's your hottest recent culinary discovery?",
	"What's your favorite kind of cooking?",
	"What food do you really, really hate?",
	"Who's your current culinary crush?"
     ].each { |name| Tag.create(tagtype: 15, isGlobal: true, name: name) }
     [ "Best Baker",
	"Griller",
	"BBQer",
	"Kid-friendly Cook",
	"Conceptual Chef",
	"Roaster with the Moster",
	"Sandwich Builder",
	"Pastry Chef",
	"Not just about Toast"
     ].each { |name| Tag.create(tagtype: 17, isGlobal: true, name: name) }
  end
end

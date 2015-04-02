class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :answer
      t.references :user, index: true
      t.integer :question_id

      t.timestamps null: false
    end
    add_foreign_key :answers, :users
    Tag.where(tagtype: 15).each { |tag| tag.destroy }
    Tag.create(tagtype: 15, isGlobal: true, name: "What's the best thing you've eaten lately?")
    Tag.create(tagtype: 15, isGlobal: true, name: "What are you all about cooking right now?")
  end
end

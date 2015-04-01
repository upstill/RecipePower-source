class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :answer
      t.references :user, index: true
      t.integer :question_id

      t.timestamps null: false
    end
    add_foreign_key :answers, :users
  end
end

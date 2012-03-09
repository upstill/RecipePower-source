class CreateFeedbacks < ActiveRecord::Migration
  def change
    create_table :feedbacks do |t|
      t.integer :user_id
      t.string :email
      t.string :wherefrom
      t.string :doing
      t.text :what

      t.timestamps
    end
  end
end

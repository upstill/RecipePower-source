class CreateReferences < ActiveRecord::Migration
  def change
    create_table :references do |t|

      t.timestamps
    end
  end
end

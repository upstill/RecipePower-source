class AddSubjectToFeedback < ActiveRecord::Migration
  def change
    add_column :feedbacks, :subject, :string
    add_column :feedbacks, :docontact, :boolean
    rename_column :feedbacks, :wherefrom, :page
    rename_column :feedbacks, :what, :comment
  end
end

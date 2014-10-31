class ChangeInCollectionDefaultInRcprefs < ActiveRecord::Migration
  def up
      change_column :rcprefs, :in_collection, :boolean, :default => false
      change_column :rcprefs, :comment, :text, :default => ""
      Rcpref.record_timestamps=false
      Rcpref.where(comment: nil).each { |rcd| 
        rcd.comment = ""
        rcd.save
	puts rcd.id.to_s
      }
      Rcpref.record_timestamps=true

  end
  def down
      change_column :rcprefs, :in_collection, :boolean, :default => true
  end
end

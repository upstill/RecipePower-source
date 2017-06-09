class AddGleaningIdToPageRef < ActiveRecord::Migration
  def up
    add_column :page_refs, :gleaning_id, :integer
    Gleaning.where.not(entity_type: nil).each { |gleaning|
      if gleaning.entity_type && (entity = gleaning.entity_type.constantize.find_by id: gleaning.entity_id)
        # puts "#{gleaning.entity_type} ##{gleaning.entity_id} has PageRef #{entity.page_ref_id}"
        entity.page_ref.update_attribute :gleaning_id, gleaning.id
      else
        puts "No #{gleaning.entity_type} ##{gleaning.entity_id} found"
        gleaning.destroy
      end
    }
  end

  def down
     remove_column :page_refs, :gleaning_id
  end
end

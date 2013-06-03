class TaggingServices
  
  # Eliminate all references to one tag in favor of another
  def self.change_tag(fromid, toid)
    Tagging.where(tag_id: fromid).each do |tochange| 
      tochange.tag_id = toid
      if Tagging.exists?(
          tag_id: tochange.tag_id, 
          user_id: tochange.user_id, 
          entity_id: tochange.entity_id, 
          entity_type: tochange.entity_type, 
          is_definition: tochange.is_definition)
        tochange.destroy # Assuming that it failed validation because not unique
      else
        tochange.save
      end
    end
  end

  # Class method meant to be run from a console, to clean up redundant taggings before adding index to prevent them
  def self.qa
    Tagging.all.each { |tagging|
      matches = Tagging.where(
        tag_id: tagging.tag_id, 
        user_id: tagging.user_id, 
        entity_id: tagging.entity_id, 
        entity_type: tagging.entity_type, 
        is_definition: tagging.is_definition)
      tagging.destroy if matches.count > 1
    }
  end

end
class TaggingServices

  def initialize taggable_entity
    @taggable_entity = taggable_entity
  end
  
  # Eliminate all references to one tag in favor of another
  def self.change_tag(fromid, toid)
    Tagging.where(tag_id: fromid).each do |tochange| 
      tochange.tag_id = toid
      if Tagging.exists?(
          tag_id: tochange.tag_id, 
          user_id: tochange.user_id, 
          entity_id: tochange.entity_id, 
          entity_type: tochange.entity_type) #,
          # is_definition: tochange.is_definition)
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
        entity_type: tagging.entity_type) # ,
        # is_definition: tagging.is_definition)
      tagging.destroy if matches.count > 1
    }
  end

  # Assert a tag associated with the given tagger. If a tag
  # given by name doesn't exist, make a new one
  def tag_with tag_or_string, options={}
    tagger_id = options[:tagger] || @taggable_entity.tag_owner
    if tag_or_string.is_a? String
      tags = Tag.strmatch tag_or_string, matchall: true, tagtype: options[:type], assert: true, userid: tagger_id
      tag = tags.first
    else
      tag = tag_or_string
    end
    @taggable_entity.tag_with tag, tagger_id
  end

end
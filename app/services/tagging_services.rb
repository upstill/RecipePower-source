class TaggingServices

  def initialize taggable_entity
    @taggable_entity = taggable_entity
  end

  # Does a tagging exist for the given entity, tag and owner?
  def exists? tag, owner_id
    Tagging.exists?(
        tag_id: tag.id,
        user_id: owner_id,
        entity_id: @taggable_entity.id,
        entity_type: @taggable_entity.class)
  end

  def assert tag, owner_id
    Tagging.find_or_create_by(
        tag_id: tag.id,
        user_id: owner_id,
        entity_id: @taggable_entity.id,
        entity_type: @taggable_entity.class.to_s)
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
  def tag_with tag_or_string, tagger_id, options={}
    if tag_or_string.is_a? String
      tags = Tag.strmatch tag_or_string, matchall: true, tagtype: options[:type], assert: true, userid: tagger_id
      tag = tags.first
    else
      tag = tag_or_string
    end
    @taggable_entity.tag_with tag, tagger_id
  end

  # Find matches for the given string among entities of the given type, in the context of an optional scope
  # Result is an array of Taggings
  def self.match matchstr, scope=nil, type_or_types=nil
    unless scope.is_a? ActiveRecord::Relation
      type_or_types, scope = scope, nil
    end
    scope ||= Tagging.unscoped
    # type_or_types can be nil (for all extant types), an array of types, or a single type
    if type_or_types
      types = type_or_types.is_a?(Array) ? type_or_types : [type_or_types]
    else
      types = scope.select(:entity_type).distinct.map(&:entity_type)
    end
    matchstr = "%#{matchstr}%" # Prep for substring matches

    types.collect do |type|
      typed_scope = (scope || Tagging.unscoped).where('taggings.entity_type = ?', type)
      # Different search for each taggable type
      case type
        when "Recipe"
          typed_scope.joins(%Q{INNER JOIN recipes ON recipes.id = taggings.entity_id}).where("recipes.title ILIKE ?", matchstr).to_a
        when "User"
          typed_scope.joins(%Q{INNER JOIN users ON users.id = taggings.entity_id}).where(
              'username ILIKE ? or
                    fullname ILIKE ? or
                    email ILIKE ? or
                    first_name ILIKE ? or
                    last_name ILIKE ? or
                    about ILIKE ?',
              matchstr, matchstr, matchstr, matchstr, matchstr, matchstr).to_a
        when "List"
          ( typed_scope.where("notes ILIKE ? or description ILIKE ?", matchstr, matchstr).to_a +
            typed_scope.joins(%Q{INNER JOIN lists ON lists.id = taggings.entity_id}).
                        joins(:tags).where('name ILIKE ?', matchstr).to_a ).uniq
        when "Site"
          # TODO: site needs to search on name
          typed_scope.where("description ILIKE ?", matchstr).to_a
        when "Feed"
          typed_scope.where("title ILIKE ? or description ILIKE ?", matchstr, matchstr).to_a
        when "FeedEntry"
          typed_scope.where("title ILIKE ? or summary ILIKE ?", matchstr, matchstr).to_a
      end
    end
  end

end

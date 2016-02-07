class TaggingServices

  def initialize taggable_entity
    @taggable_entity = taggable_entity
  end

  # Shop for taggings according to various criteria
  def filtered_taggings options={}
    scope = @taggable_entity.taggings
    uid = options[:user_id] || (options[:user].id if options[:user])
    scope = scope.where(user_id: uid) if uid
    scope = scope.
        joins('INNER JOIN tags ON tags.id = taggings.tag_id').
        where("tags.tagtype = #{Tag.typenum(options[:tagtype])}") if options[:tagtype]
    scope
  end

  # Glean the taggings to this entity by a given user, of a given type
  def taggings user=nil, tagtype=nil
    unless user.is_a? User
      user, tagtype = nil, user
    end
    scope = @taggable_entity.taggings
    scope = scope.where(user_id: user.id) if user
    scope = scope.
        joins('INNER JOIN tags ON tags.id = taggings.tag_id').
        where("tags.tagtype = #{Tag.typenum(tagtype)}") if tagtype
    scope
  end

  def tags user=nil, tagtype=nil
    taggings(user, tagtype).includes(:tag).map &:tag
  end

  def filtered_tags options={}
    filtered_taggings(options).includes(:tag).map &:tag
  end

  # Does a tagging exist for the given entity, tag and owner?
  # Sets of each are allowed, whether id numbers or objects
  # The latter may also be nil, to find taggings by anyone
  def exists? tag_or_tags_or_id_or_ids, owners_or_ids=nil
    tag_ids = (tag_or_tags_or_id_or_ids.is_a?(Array) ? tag_or_tags_or_id_or_ids : [ tag_or_tags_or_id_or_ids ] ).collect { |tag_or_id|
      tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id
    }
    return false if tag_ids.empty? # Empty in, empty out
    tag_ids = tag_ids.first if tag_ids.count == 1
    query = { tag_id: tag_ids,
              entity_id: @taggable_entity.id,
              entity_type: @taggable_entity.class }

    if owners_or_ids
      owner_ids = (owners_or_ids.is_a?(Array) ? owners_or_ids : [ owners_or_ids ] ).collect { |owner_or_id|
        owner_or_id.is_a?(Fixnum) ? owner_or_id : owner_or_id.id
      }
      query[:user_id] = ((owner_ids.count == 1) ? owner_ids.first : owner_ids) unless owner_ids.empty?
    end
    Tagging.where(query).any?
  end

  def assert tag, owner_id
    Tagging.find_or_create_by(
        tag_id: tag.id,
        user_id: owner_id,
        entity_id: @taggable_entity.id,
        entity_type: @taggable_entity.class.to_s)
  end

  def refute tag, owner_id
    if tagging = Tagging.find_by(
        tag_id: tag.id,
        user_id: owner_id,
        entity_id: @taggable_entity.id,
        entity_type: @taggable_entity.class.to_s)
      tagging.destroy
    end
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
          ( typed_scope.joins(%Q{INNER JOIN lists ON lists.id = taggings.entity_id}).where("lists.notes ILIKE ? or lists.description ILIKE ?", matchstr, matchstr).to_a +
            typed_scope.joins(%Q{INNER JOIN lists ON lists.id = taggings.entity_id}).
                        joins(:tag).where('name ILIKE ?', matchstr).to_a ).uniq
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

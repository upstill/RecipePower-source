class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list
    self.list = list
  end

  # A list "includes" an item if
  # 1) it is stored directly in the list, or
  # 2) it is tagged by the list's tag
  # 3) the list "pulls in" entities using its tags AND the entity is tagged by the list's tags
  def include? entity, user_or_id, with_pullins=true
    # Trivial accept if the entity is physically in among the list items
    return true if @list.stores? entity
    uid = user_or_id.is_a?(Fixnum) ? user_or_id : user_or_id.id
    ts = TaggingServices.new entity
    # It's included if the owner or this user has tagged it with the name tag
    return true if ts.exists? @list.name_tag_id, (uid == @list.owner_id ? uid : [ uid, @list.owner_id ])
    # If not directly tagged, it's included if it's tagged with any of the list's tags, BY ANYONE (?)
    return false unless with_pullins && @list.pullin
    ts.exists? pulled_tag_ids
  end

  # Append an entity to the list, which involves:
  # 1) ensuring that the entity appears in the ordering, appending it to the end if not (list owner only)
  # 2) tagging the entity with the list's tag as the given user
  # 3) adding the entity to the owner's collection
  def include entity, user_or_id
    uid = (user_or_id.is_a?(Fixnum) ? user_or_id : user_or_id.id)
    @list.store entity if uid==owner_id
    TaggingServices.new(entity).assert @list.name_tag, uid # Tag with the list's name tag anyway
    # owner.touch entity
  end

  # Add an entity to the list based on parameters
  def include_by entity_type, entity_id, user_id
    if entity = entity_type.singularize.camelize.constantize.find(entity_id)
      include entity, user_id
    end
  end

  def exclude entity, user_or_id
    uid = (user_or_id.is_a?(Fixnum) ? user_or_id : user_or_id.id)
    if uid == owner_id
      @list.remove entity
      yield if block_given?
    end
    TaggingServices.new(entity).refute @list.name_tag, uid # Tag with the list's name tag anyway
  end

  # Remove an entity from the list based on parameters
  def exclude_by entity_type, entity_id, user_id
    if entity = entity_type.singularize.camelize.constantize.find(entity_id)
      exclude entity, user_id
    end
  end

  # Get the official list of tags that pull in entities: those which were applied by the list owner
  def pulled_tags
    @list.pullin ? @list.taggings.where(user_id: @list.owner_id).includes(:tag).map(&:tag) : []
  end

  def pulled_tag_ids
    @list.pullin ? @list.taggings.where(user_id: @list.owner_id).map(&:tag_id) : []
  end

  # Return the set of lists containing the entity (either directly or indrectly) that are visible to the given user
    def self.find_by_listee taggable_entity
      viewer = User.find(taggable_entity.tagging_user_id || User.super_id)
      list_scope = self.lists_visible_to viewer, true
      friend_ids = viewer.followee_ids + [taggable_entity.tagging_user_id, User.super_id]
      tag_ids = taggable_entity.taggings.where(user_id: friend_ids).pluck(:tag_id)
      list_tag_ids = Tag.where(id: tag_ids, tagtype: 16).pluck :id
      tag_id_str = tag_ids.map(&:to_s).join ','


      indirect = tag_ids.blank? ? [] : list_scope.where(pullin: true).joins(:taggings).where("taggings.tag_id in (#{tag_id_str})").to_a
      # Collect all the lists whose owners included the entity in the list directly
      direct = Tagging.where(user_id: friend_ids, entity: taggable_entity, tag_id: list_tag_ids).collect { |tagging|
        list_scope.find_by owner_id: tagging.user_id, name_tag_id: tagging.tag_id
      }.compact
      (direct+indirect).uniq(&:id)
    end

    # Provide a scope for the lists visible to the given user
    def self.lists_visible_to user, with_owned=false
      friend_ids = (user.followee_ids + [User.super_id]).map(&:to_s).join(',')
      if with_owned
        owner_clause = "(owner_id = #{user.id}) or "
      else
        owner_clause = "(owner_id != #{user.id}) and "
      end
      List.where "#{owner_clause}(availability = 0 or (availability = 1 and owner_id in (#{friend_ids})))"
    end

    def available_to? user
      (user.id == @list.owner.id) || # always available to owner
          (user.name == "super") || # always available to super
          (@list.typesym == :public) || # always available if public
          ((@list.typesym == :friends) && (@list.owner.follows? user)) # available to friends
    end

    # Return a scope on the Tagging table for the unfiltered contents of the list
    def tagging_scope viewerid=nil
      # We get everything tagged either directly by the list tag, or indirectly via
      # the included tags, EXCEPT for other users' tags using the list's tag
      tag_ids = [@list.name_tag_id]
      tagger_id_or_ids = [@list.owner_id, viewerid].compact.uniq
      whereclause = tagger_id_or_ids.count > 1 ?
          "(user_id in (#{tagger_id_or_ids.join ','}))" :
          "(user_id = #{tagger_id_or_ids = tagger_id_or_ids.first})"
      whereclause << " or (tag_id != #{@list.name_tag_id})"
      # If the pullin flag is on, we also include material tagged with the tags applied to the list itself
      # BY ITS OWNER
      if @list.pullin
        @list.taggings.where(user_id: tagger_id_or_ids).each do |tagging|
          tag_ids << tagging.tag_id
          tag_ids += TagServices.new(tagging.tag).similar_ids
        end
        tag_ids.uniq!
        whereclause = "(#{whereclause}) and not (entity_type = 'List' and entity_id = #{@list.id})"
      end
      scope = Tagging.where(tag_id: (tag_ids.count>1 ? tag_ids : tag_ids.first)).where whereclause
      scope
    end

    def self.study_users
      User.all.collect { |user|
        user.collection_tags.collect { |tag|
          if (ct = tag.recipes(user.id).count) > 0
            "User ##{user.id} has #{ct} recipes in #{tag.name} collection."
          end
        }+
            user.lists.collect { |list|
              if (ct = list.entity_count) > 0
                "User ##{user.id} has #{ct} recipes in #{list.name} list."
              end
            }
      }.flatten.compact.each { |str| puts str }
      ""
    end

  end

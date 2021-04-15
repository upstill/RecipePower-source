class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list_or_decorator
    self.list = list_or_decorator.is_a?(Draper::Decorator) ? list_or_decorator.object : list_or_decorator
  end

  # Get the lists on which the entity appears, as visible to the user
  def self.associated_lists_with_status entity_or_decorator, user=User.current_or_guest
    def self.accept_if list, status
      [list, status] if list
    end

    decorator = entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator : entity_or_decorator.decorate
    ts = TaggingServices.new decorator.object
    # The lists that the given object appear on FOR THIS USER are those that
    # are tagged either by the user or by the list owner

    # The tags the user has applied map back to a list.
    # If the user owns the list (possibly by creating it from the tag), it gets the status :owned
    # If it already exists, it gets the status :contributed
    user_tags = ts.filtered_tags(:user => user, :tagtype => :List) # ts.tags provides all the list taggings BY THIS USER
    (user_tags.collect { |user_tag|
      list_scope = user_tag.dependent_lists
      accept_if(list_scope.where(owner: user).first, :owned) ||
          accept_if(list_scope.where(ListServices.availability_query(user)).first, :contributed) ||
          # List tag but no list! Assert the list as owned by the user UNLESS there's already an invisible list by that name
          (accept_if(List.create(name_tag: user_tag, owner: user), :owned) unless list_scope.exists?)
    } +
        # The item may also be included in the list by
        # -- its owner (if they allow it to be seen) => :friends
        # -- or publicly => :public
        (ts.tags(:List) - user_tags).collect { |other_tag|
          accept_if(self.friend_lists_on_tag(decorator, other_tag, user).first, :friends) ||
              accept_if(other_tag.public_lists.first, :public) # There's at least one publicly available list using this tag as title
        }).compact
  end

  # Compile the set of lists associated with an object, leaving the status intact but optionally uniquifying the lists
  def self.associated_lists entity_or_decorator, user=User.current_or_guest
    lws = self.associated_lists_with_status(entity_or_decorator, user)
    # Execute the optional block on each, returning the lists only
    if block_given?
      lws.collect { |arr| yield(*arr); arr.first }.uniq
    else
      lws.map(&:first).uniq
    end
  end

  # Provide a scope for the lists visible to the given user
  def self.availability_query user, with_owned=false
    friend_ids = (user.followee_ids + [User.super_id]).map(&:to_s).join(',')
    if with_owned
      owner_clause = "(owner_id = #{user.id}) or "
    else
      owner_clause = "(owner_id != #{user.id}) and "
    end
    "#{owner_clause}(availability = 0 or (availability = 1 and owner_id in (#{friend_ids})))"
  end

  def self.visible_lists viewer, with_owned=false
    List.where ListServices.availability_query(viewer, with_owned)
  end

  # Tagging by a friend on a list they own
  def self.friend_lists_on_tag decorator, tag, user
    # What lists are visible:
    # 1) All public lists owned by friends
    # 2) All friends-only lists owned by friends who also follow the user (thus allowing access to friends-only lists)
    return tag.dependent_lists.none if user.followee_ids.empty?
    query = "(lists.availability = 0 AND lists.owner_id in (#{user.followee_ids.join(', ')}))"
    if (extras = user.followee_ids & user.collector_ids).present?
      query << " OR (lists.availability = 1 AND lists.owner_id in (#{extras.join(', ')}))"
      Rails.logger.debug 'extras: ' + extras.sort.join(', ')
    end
    # HOWEVER: since many people may use the list's tag, we only present
    # lists for an entity when the owner of the list has tagged the entity with the list's name tag
    tag.
        dependent_lists.
        where(query).
        joins("INNER JOIN taggings ON taggings.user_id = lists.owner_id and taggings.entity_id = #{decorator.id} and taggings.entity_type = '#{decorator.object.class}'").
        uniq
  end

  # List tags are handled specially, due to ownership of lists
  def self.associate entity_or_decorator, ntags, user=User.current
    decorator = entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator : entity_or_decorator.decorate
    otags = ListServices.associated_lists(decorator, user).map &:name_tag
    (ntags - otags).each { |list_tag| decorator.assert_tagging list_tag, user.id }
    (otags - ntags).each do |list_tag|
      if owned_list = list_tag.dependent_lists.where(owner_id: user.id).first
        ListServices.new(owned_list).exclude decorator.object, user.id
      else
        decorator.refute_tagging list_tag, user.id
      end
    end
    ntags.each { |list_tag|
      list_tag.dependent_lists.where(owner_id: user.id).each { |list|
        list.store decorator.object
      }
    }
  end

  # A list "includes" an item if
  # 1) it is stored directly in the list, or
  # 2) it is tagged by the list's tag
  # 3) the list "pulls in" entities using its tags AND the entity is tagged by the list's tags
  def include? entity, user_or_id, with_pullins=true
    # Trivial accept if the entity is physically in among the list items
    return true if @list.stores? entity
    user_id = user_or_id.is_a?(Integer) ? user_or_id : user_or_id.id
    ts = TaggingServices.new entity
    # It's included if the owner or this user has tagged it with the name tag
    return true if ts.exists? @list.name_tag_id, (user_id == @list.owner_id ? user_id : [user_id, @list.owner_id])
    # If not directly tagged, it's included if it's tagged with any of the list's tags, BY ANYONE (?)
    return false unless with_pullins && @list.pullin
    ts.exists? pulled_tag_ids
  end

  # Append an entity to the list, which involves:
  # 1) ensuring that the entity appears in the ordering, appending it to the end if not (list owner only)
  # 2) tagging the entity with the list's tag as the given user
  # 3) adding the entity to the owner's collection
  def include entity, user_or_id
    user_id = (user_or_id.is_a?(Integer) ? user_or_id : user_or_id.id)
    @list.store entity if user_id==owner_id
    # TaggingServices.new(entity).assert @list.name_tag, user_id # Tag with the list's name tag anyway
    entity.assert_tagging @list.name_tag, user_id # Tag with the list's name tag anyway
    # owner.touch entity
  end

  # Return an array of the entities in the list, visible to the given viewer
  def entities viewerid=nil
    tagging_query(viewerid).to_a.map(&:entity)
  end

  # Add an entity to the list based on parameters
  def include_by entity_type, entity_id, user_id
    if entity = entity_type.singularize.camelize.constantize.find(entity_id)
      include entity, user_id
    end
  end

  def exclude entity, user_or_id
    user_id = (user_or_id.is_a?(Integer) ? user_or_id : user_or_id.id)
    @list.remove entity if user_id == owner_id
    # TaggingServices.new(entity).refute @list.name_tag, user_id # Remove tagging (from this user's perspective)
    entity.refute_tagging @list.name_tag, user_id # Remove tagging (from this user's perspective)
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

  def tagging_query viewerid=User.current_or_guest.id
    Tagging.list_scope @list, viewerid
  end

  # Return a scope on a given type of entity for list members visible by the viewer
  def entity_scope type, viewer
    # type.constantize.tagged_by list.name_tag, [ list.owner_id, viewer.id ]
    type.constantize.joins(:taggings).merge(Tagging.list_scope @list, viewer.id)
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
    }.flatten.compact.each { |str| Rails.logger.debug str }
    ""
  end

end

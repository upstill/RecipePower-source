class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list
    self.list = list
  end

  # Return the set of lists containing the entity (either directly or indrectly) that are visible to the given user
  def self.find_by_listee taggable_entity
    uid = taggable_entity.tagging_user_id || User.super_id
    list_scope = self.find_visible_to uid, true
    friend_ids = User.find(uid).followee_ids + [taggable_entity.tagging_user_id, User.super_id]
    tag_ids = taggable_entity.taggings.where(user_id: friend_ids).pluck(:tag_id)
    list_tag_ids = Tag.where(id: tag_ids, tagtype: 16).pluck :id
    tag_id_str = tag_ids.map(&:to_s).join ','


    indirect = tag_ids.blank? ? [] : list_scope.where(pullin: true).joins(:taggings).where("taggings.tag_id in (#{tag_id_str})").to_a
    # Get lists in which the owner has tagged the entity directly
=begin
    This doesn't work because of cross-talk between taggings among all users. There seems to be no
    way to use a join for the purpose. But the number of taggings ought to be small, so iteration isn't too bad
    direct = list_tag_ids_str.blank? ?
        [] :
        List.joins( %Q{ INNER JOIN taggings on taggings.tag_id = lists.name_tag_id
              where taggings.user_id in (#{friend_ids_str}) and
                    taggings.entity_type = '#{eclass}' and
                    taggings.entity_id = #{eid} and
                    lists.name_tag_id IN (#{list_tag_ids_str}) and
                    ( (lists.owner_id = #{uid}) or
                      (lists.availability = 0 or
                      (lists.availability = 1 and lists.owner_id in (#{friend_ids_str}))))
      }).to_a
=end
    # Collect all the lists whose owners included the entity in the list directly
    direct = Tagging.where(user_id: friend_ids, entity: taggable_entity, tag_id: list_tag_ids).collect { |tagging|
      list_scope.find_by owner_id: tagging.user_id, name_tag_id: tagging.tag_id
    }.compact
    (direct+indirect).uniq(&:id)
  end

  def self.find_visible_to uid, with_owned=false
    friend_ids = (User.find(uid).followee_ids + [User.super_id]).map(&:to_s).join(',')
    if with_owned
      owner_clause = "(owner_id = #{uid}) or "
    else
      owner_clause = "(owner_id != #{uid}) and "
    end
    List.where "#{owner_clause}(availability = 0 or (availability = 1 and owner_id in (#{friend_ids})))"
=begin
    List.joins("INNER JOIN taggings as t1 on t1.entity_type = 'List' and t1.entity_id = 631 INNER JOIN taggings as t2 on t2.entity_id = 4 and t2.entity_type = 'Recipe' and t1.tag_id = t2.tag_id")
    Tagging.where(entity: l).joins("INNER JOIN taggings as t2 on taggings.tag_id = t2.tag_id").where("t2.entity_type = 'Recipe' and t2.entity_id = 4")
    Tagging Load (73.5ms)  SELECT "taggings".* FROM "taggings" INNER JOIN taggings as t2 on taggings.tag_id = t2.tag_id WHERE "taggings"."entity_type" = 'List' AND "taggings"."entity_id" = 631 AND (t2.entity_type = 'Recipe' and t2.entity_id = 4)
=end
  end

  def available_to? user
    (user.id == @list.owner.id) || # always available to owner
    (user.name == "super") || # always available to super
    (@list.typesym == :public) || # always available if public
    ((@list.typesym == :friends) && (@list.owner.follows? user)) # available to friends
  end

  # Return a scope on the Tagging table for the unfiltered contents of the list
  def tagging_scope userid=nil
    # We get everything tagged either directly by the list tag, or indirectly via
    # the included tags, EXCEPT for other users' tags using the list's tag
    tag_ids = [ @list.name_tag_id ]
    # If the pullin flag is on, we also include material tagged with the tags applied to the list itself
    # BY ITS OWNER
    whereclause = "(user_id = #{@list.owner_id}) or (tag_id != #{@list.name_tag_id})"
    if @list.pullin
      tag_ids += @list.taggings.where(user_id: @list.owner_id).pluck(:tag_id)
      whereclause = "(#{whereclause}) and not (entity_type = 'List' and entity_id = #{@list.id})"
    end
    scope = Tagging.where( tag_id: (tag_ids.count>1 ? tag_ids : tag_ids.first)).where whereclause
    scope
  end

  # Move each of the user's collections into a list
  # TODO: remove all these after collections migrate to lists
  def self.adopt_collections
    superu = User.find User.super_id
    list = nil
    # For each user that's actually a channel, create a list
    User.where('channel_referent_id > 0').each { |channel_user|
      list = List.assert channel_user.channel.name, superu, create: true
      channel_user.collection_pointers.where(in_collection: true).map(&:entity).each { |entity|
        list.include(entity) unless list.include?(entity)
      }
      list.included_tags = channel_user.tags
      list.availability = 1
      list.save
      channel_user.destroy
    }
    User.all.each { |user|
      nlists = user.collection_pointers.where("entity_type = 'List'").count
      ncollections = PrivateSubscription.where("user_id = #{user.id}").count
      puts "#{user.handle} has #{ncollections} collections and #{nlists} lists before."
      subs = PrivateSubscription.where("user_id = #{user.id}")
      subs.each { |sub|
        tag = sub.tag
        list = List.assert tag.name, user, create: true
        list.availability = 1
        tag.recipes(user.id).each { |entity|
          list.include(entity) unless list.include?(entity)
        }
        list.save
        sub.destroy
      }
      nlists = user.collection_pointers.where("entity_type = 'List'").count
      ncollections = PrivateSubscription.where("user_id = #{user.id}").count
      puts "#{user.handle} has #{ncollections} collections and #{nlists} list afterward."
    }
    List.all.each { |l| l.availability = 1; l.save }
    ups = User.find 3
    gar = User.find 1
    superu.owned_lists.each { |l|
      ups.collect l
      gar.collect l
      l.save
    }
    ups.save
    gar.save
    list
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

class ListServices

  attr_accessor :list

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :list

  def initialize list
    self.list = list
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
    tag_ids += @list.taggings.where(user_id: @list.owner_id).map(&:tag_id) if @list.pullin
    scope = Tagging.where( tag_id: (tag_ids.count>1 ? tag_ids : tag_ids.first)).
        where("(user_id = #{@list.owner_id}) or (tag_id != #{@list.name_tag_id})")
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
